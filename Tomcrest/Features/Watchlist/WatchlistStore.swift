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
    var folderSortMode: WatchlistFolderSortMode {
        didSet { UserDefaults.standard.set(folderSortMode.rawValue, forKey: Self.folderSortModeKey) }
    }
    var isLoading = false
    var errorMessage: String?

    private var auth: AuthSession?
    private var debounceTask: Task<Void, Never>?
    private var isPersisting = false
    private var needsSyncAfterPersist = false
    private var hasLoaded = false
    private static let folderSortModeKey = "watchlist.folderSortMode"
    private static let legacySymbolSortModeKey = "watchlist.symbolSortMode"

    init() {
        let storedRaw = UserDefaults.standard.string(forKey: Self.folderSortModeKey)
            ?? UserDefaults.standard.string(forKey: Self.legacySymbolSortModeKey)
        if let raw = storedRaw, let mode = WatchlistFolderSortMode(rawValue: raw) {
            folderSortMode = mode
        } else {
            folderSortMode = .custom
        }
    }

    func bind(auth: AuthSession) {
        self.auth = auth
    }

    func reset() {
        debounceTask?.cancel()
        debounceTask = nil
        isPersisting = false
        needsSyncAfterPersist = false
        folders = []
        editingFolderID = nil
        customizingFolderID = nil
        showingNewFolderSheet = false
        activeDragSymbol = nil
        isLoading = false
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
        sortFolders(folders.filter(\.isPinned)) + sortFolders(folders.filter { !$0.isPinned })
    }

    var pinnedFolders: [WatchlistFolder] {
        sortFolders(folders.filter(\.isPinned))
    }

    var regularFolders: [WatchlistFolder] {
        sortFolders(folders.filter { !$0.isPinned })
    }

    private func sortFolders(_ folders: [WatchlistFolder]) -> [WatchlistFolder] {
        switch folderSortMode {
        case .custom:
            return folders.sorted { $0.sortOrder < $1.sortOrder }
        case .name:
            return folders.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .dateAdded:
            return folders.sorted { lhs, rhs in
                let left = lhs.createdAt ?? .distantPast
                let right = rhs.createdAt ?? .distantPast
                if left != right { return left > right }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
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
                dayChangePercent: 0,
                createdAt: Date()
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
            applyWorkspace(response)

            if folders.isEmpty, !localSymbols.isEmpty, migrating {
                seedFromLocalSymbols(localSymbols)
                await persistWorkspaceImmediately(applyResponse: true)
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
                dayChangePercent: 0,
                createdAt: Date()
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
        var mapped = WatchlistAPIMapping.folders(from: response)
        for index in mapped.indices where mapped[index].createdAt == nil {
            mapped[index].createdAt = folders.first(where: { $0.id == mapped[index].id })?.createdAt
        }
        folders = mapped
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
                if folders[folderIndex].symbols[symbolIndex].createdAt == nil,
                   let createdAt = dto.createdAt.flatMap(DateFormatters.parse) {
                    folders[folderIndex].symbols[symbolIndex].createdAt = createdAt
                }
            }
        }
    }

    private func scheduleSync() {
        guard hasLoaded, auth?.accessToken != nil else { return }

        if isPersisting {
            needsSyncAfterPersist = true
            return
        }

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await self?.persistWorkspaceImmediately()
        }
    }

    private func persistWorkspaceImmediately(applyResponse: Bool = false) async {
        guard let auth, let token = auth.accessToken else { return }

        isPersisting = true
        defer {
            isPersisting = false
            if needsSyncAfterPersist {
                needsSyncAfterPersist = false
                scheduleSync()
            }
        }

        do {
            let payload = WatchlistAPIMapping.syncRequest(from: folders)
            let response = try await WatchlistService.syncWorkspace(payload, accessToken: token)
            if applyResponse {
                applyWorkspace(response)
            }
            errorMessage = nil
        } catch {
            guard !shouldIgnoreSyncError(error) else { return }
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
        if shouldIgnoreSyncError(error) {
            return ""
        }
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

    private func shouldIgnoreSyncError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if Task.isCancelled { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }

        let normalized = error.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized == "cancelled" || normalized == "canceled"
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
            sortOrder: order,
            createdAt: Date()
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

        folderSortMode = .custom
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
        folderSortMode = .custom
        var section = folders
            .filter { inPinnedSection ? $0.isPinned : !$0.isPinned }
            .sorted { $0.sortOrder < $1.sortOrder }
        section.move(fromOffsets: source, toOffset: destination)
        for (offset, folder) in section.enumerated() {
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].sortOrder = offset + (inPinnedSection ? 0 : pinnedSectionCount)
            }
        }
        scheduleSync()
    }

    private var pinnedSectionCount: Int {
        folders.filter(\.isPinned).count
    }

    private func normalizeSortOrders() {
        let pinned = folders.filter(\.isPinned).sorted { $0.sortOrder < $1.sortOrder }
        let regular = folders.filter { !$0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }

        for (offset, folder) in pinned.enumerated() {
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].sortOrder = offset
            }
        }
        for (offset, folder) in regular.enumerated() {
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].sortOrder = offset + pinned.count
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
