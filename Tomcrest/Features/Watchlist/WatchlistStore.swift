import Foundation
import SwiftUI

@MainActor
@Observable
final class WatchlistStore {
    var folders: [WatchlistFolder] = []
    var editingFolderID: UUID?
    var customizingFolderID: UUID?
    var showingNewFolderSheet = false
    var activeDragSymbol: WatchlistSymbolDragPayload?
    var isLoading = false
    var isSyncing = false
    var errorMessage: String?

    private var auth: AuthSession?
    private var syncTask: Task<Void, Never>?
    private var hasLoaded = false

    init() {}

    func bind(auth: AuthSession) {
        self.auth = auth
    }

    func reset() {
        syncTask?.cancel()
        syncTask = nil
        folders = []
        editingFolderID = nil
        customizingFolderID = nil
        showingNewFolderSheet = false
        activeDragSymbol = nil
        isLoading = false
        isSyncing = false
        errorMessage = nil
        hasLoaded = false
        ResearchSymbolStorage.clearAll()
    }

    var allTickers: [String] {
        Array(
            Set(
                folders.flatMap { folder in
                    folder.symbols.map { $0.ticker.uppercased() }
                }
            )
        ).sorted()
    }

    var hasSymbols: Bool {
        !allTickers.isEmpty
    }

    func contains(_ symbol: String) -> Bool {
        allTickers.contains(symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    var sortedFolders: [WatchlistFolder] {
        folders.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var pinnedFolders: [WatchlistFolder] {
        sortedFolders.filter(\.isPinned)
    }

    var regularFolders: [WatchlistFolder] {
        sortedFolders.filter { !$0.isPinned }
    }

    func folder(id: UUID) -> WatchlistFolder? {
        folders.first { $0.id == id }
    }

    func swatch(for folder: WatchlistFolder) -> WatchlistSwatch {
        WatchlistPremiumPalette.swatch(id: folder.swatchID)
    }

    func accentColor(for folder: WatchlistFolder) -> Color {
        if let hex = folder.accentHex {
            return Color(hex: hex)
        }
        return swatch(for: folder).accentColor
    }

    func folderDayChange(_ folder: WatchlistFolder) -> (value: Double, percent: Double) {
        guard !folder.symbols.isEmpty else { return (0, 0) }
        let total = folder.symbols.reduce(0) { $0 + $1.dayChange }
        let avgPct = folder.symbols.reduce(0) { $0 + $1.dayChangePercent } / Double(folder.symbols.count)
        return (total, avgPct)
    }

    // MARK: - Star / Research

    func ensureLoaded() async {
        if auth?.accessToken != nil, !hasLoaded {
            await load(localSymbols: ResearchSymbolStorage.watchlist())
        }
    }

    func isSymbol(_ ticker: String, inFolderID folderID: UUID) -> Bool {
        let upper = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let folder = folder(id: folderID) else { return false }
        return folder.symbols.contains { $0.ticker == upper }
    }

    func addSymbol(_ symbol: String, companyName: String?, toFolderID folderID: UUID) {
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty,
              let index = folders.firstIndex(where: { $0.id == folderID }),
              !folders[index].symbols.contains(where: { $0.ticker == upper }) else { return }

        folders[index].symbols.append(
            WatchlistSymbol(
                id: UUID(),
                ticker: upper,
                companyName: companyName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? upper,
                price: 0,
                dayChange: 0,
                dayChangePercent: 0
            )
        )
        mirrorLocalCache()
        scheduleSync()
    }

    func removeSymbol(_ symbol: String, fromFolderID folderID: UUID) {
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty,
              let index = folders.firstIndex(where: { $0.id == folderID }) else { return }

        folders[index].symbols.removeAll { $0.ticker == upper }
        mirrorLocalCache()
        scheduleSync()
    }

    // MARK: - Loading / sync

    func load(localSymbols: [String] = []) async {
        guard let auth, let token = auth.accessToken else {
            if !localSymbols.isEmpty, folders.isEmpty {
                seedFromLocalSymbols(localSymbols)
                mirrorLocalCache()
            }
            return
        }

        isLoading = true
        errorMessage = nil
        let migrating = !hasLoaded
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let response = try await WatchlistService.fetchWorkspace(accessToken: token)
            folders = WatchlistAPIMapping.folders(from: response)
            mirrorLocalCache()

            if folders.isEmpty, !localSymbols.isEmpty, migrating {
                seedFromLocalSymbols(localSymbols)
                await persistWorkspaceImmediately()
            }
        } catch {
            if migrating, !localSymbols.isEmpty {
                seedFromLocalSymbols(localSymbols)
                mirrorLocalCache()
                errorMessage = "Using offline symbols until sync succeeds."
            } else {
                errorMessage = userFacingError(error)
            }
        }
    }

    func refreshQuotes() async {
        guard let auth, let token = auth.accessToken else { return }

        do {
            let response = try await WatchlistService.fetchWorkspace(
                accessToken: token,
                includeQuotes: true
            )
            applyQuotes(from: response)
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    private func seedFromLocalSymbols(_ symbols: [String]) {
        let items = symbols.map { ticker in
            WatchlistSymbol(
                id: UUID(),
                ticker: ticker.uppercased(),
                companyName: ticker.uppercased(),
                price: 0,
                dayChange: 0,
                dayChangePercent: 0
            )
        }

        folders = [
            WatchlistFolder(
                id: UUID(),
                name: "Saved",
                iconName: "star.fill",
                symbols: items,
                swatchID: "slate",
                accentHex: nil,
                isPinned: true,
                isCollapsed: false,
                sortOrder: 0
            ),
        ]
        normalizeSortOrders()
    }

    private func applyWorkspace(_ response: WatchlistWorkspaceResponse) {
        folders = WatchlistAPIMapping.folders(from: response)
        mirrorLocalCache()
    }

    private func applyQuotes(from response: WatchlistWorkspaceResponse) {
        let quotesByID: [String: WatchlistSymbolDTO] = Dictionary(
            uniqueKeysWithValues: response.folders
                .flatMap(\.symbols)
                .map { ($0.id, $0) }
        )

        for folderIndex in folders.indices {
            for symbolIndex in folders[folderIndex].symbols.indices {
                let symbolID = folders[folderIndex].symbols[symbolIndex].id.uuidString
                guard let dto = quotesByID[symbolID] else { continue }
                folders[folderIndex].symbols[symbolIndex].companyName = dto.companyName
                folders[folderIndex].symbols[symbolIndex].price = dto.price ?? 0
                folders[folderIndex].symbols[symbolIndex].dayChange = dto.dayChange ?? 0
                folders[folderIndex].symbols[symbolIndex].dayChangePercent = dto.dayChangePercent ?? 0
            }
        }
    }

    private func scheduleSync() {
        guard hasLoaded, auth?.accessToken != nil else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await self?.persistWorkspaceImmediately()
        }
    }

    private func persistWorkspaceImmediately() async {
        guard let auth, let token = auth.accessToken else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let payload = WatchlistAPIMapping.syncRequest(from: folders)
            let response = try await WatchlistService.syncWorkspace(payload, accessToken: token)
            applyWorkspace(response)
            errorMessage = nil
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    private func mirrorLocalCache() {
        ResearchSymbolStorage.replaceWatchlist(allTickers)
    }

    private func locateSymbol(_ ticker: String) -> (folderIndex: Int, symbolIndex: Int)? {
        for (folderIndex, folder) in folders.enumerated() {
            if let symbolIndex = folder.symbols.firstIndex(where: { $0.ticker == ticker }) {
                return (folderIndex, symbolIndex)
            }
        }
        return nil
    }

    private func userFacingError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .decoding:
                return "Couldn't load your watchlist. Pull to refresh or try again shortly."
            default:
                return apiError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    // MARK: - Folder actions

    func toggleCollapse(folderID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            folders[index].isCollapsed.toggle()
        }
        scheduleSync()
    }

    func togglePin(folderID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            folders[index].isPinned.toggle()
            normalizeSortOrders()
        }
        scheduleSync()
    }

    func renameFolder(id: UUID, name: String, iconName: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        folders[index].iconName = iconName.isEmpty ? WatchlistFolderIcons.defaultIcon : iconName
        scheduleSync()
    }

    func deleteFolder(id: UUID) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            folders.removeAll { $0.id == id }
            normalizeSortOrders()
        }
        mirrorLocalCache()
        scheduleSync()
    }

    func addFolder(name: String, iconName: String, swatchID: WatchlistSwatch.ID) {
        let order = (folders.map(\.sortOrder).max() ?? -1) + 1
        let folder = WatchlistFolder(
            id: UUID(),
            name: name,
            iconName: iconName.isEmpty ? WatchlistFolderIcons.defaultIcon : iconName,
            symbols: [],
            swatchID: swatchID,
            accentHex: nil,
            isPinned: false,
            isCollapsed: false,
            sortOrder: order
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
            folders.append(folder)
        }
        scheduleSync()
    }

    func updateFolderStyle(id: UUID, swatchID: WatchlistSwatch.ID, accentHex: UInt32?) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].swatchID = swatchID
        folders[index].accentHex = accentHex
        scheduleSync()
    }

    func moveFolder(draggedID: UUID, before targetID: UUID) {
        guard draggedID != targetID,
              var dragged = folders.first(where: { $0.id == draggedID }),
              let target = folders.first(where: { $0.id == targetID }),
              dragged.isPinned == target.isPinned else { return }

        folders.removeAll { $0.id == draggedID }
        guard let targetIndex = folders.firstIndex(where: { $0.id == targetID }) else {
            folders.append(dragged)
            normalizeSortOrders()
            scheduleSync()
            return
        }
        dragged.sortOrder = target.sortOrder
        folders.insert(dragged, at: targetIndex)
        normalizeSortOrders()
        scheduleSync()
    }

    func reorderFolders(inPinnedSection: Bool, from source: IndexSet, to destination: Int) {
        var section = inPinnedSection ? pinnedFolders : regularFolders
        section.move(fromOffsets: source, toOffset: destination)
        for (offset, folder) in section.enumerated() {
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].sortOrder = offset + (inPinnedSection ? 0 : pinnedFolders.count)
            }
        }
        scheduleSync()
    }

    private func normalizeSortOrders() {
        for (offset, folder) in sortedFolders.enumerated() {
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].sortOrder = offset
            }
        }
    }

    // MARK: - Symbol actions

    func moveSymbol(_ payload: WatchlistSymbolDragPayload, to destinationFolderID: UUID) {
        guard payload.sourceFolderID != destinationFolderID,
              let sourceIndex = folders.firstIndex(where: { $0.id == payload.sourceFolderID }),
              let symbolIndex = folders[sourceIndex].symbols.firstIndex(where: { $0.id == payload.symbolID }),
              let destIndex = folders.firstIndex(where: { $0.id == destinationFolderID }) else { return }

        let symbol = folders[sourceIndex].symbols.remove(at: symbolIndex)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            folders[destIndex].symbols.append(symbol)
        }
        mirrorLocalCache()
        scheduleSync()
    }

    func reorderSymbols(in folderID: UUID, from source: IndexSet, to destination: Int) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].symbols.move(fromOffsets: source, toOffset: destination)
        scheduleSync()
    }

    func removeSymbol(folderID: UUID, symbolID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].symbols.removeAll { $0.id == symbolID }
        mirrorLocalCache()
        scheduleSync()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
