import Foundation
import SwiftUI

@MainActor
@Observable
final class WatchlistStore {
    let quoteStore = WatchlistQuoteStore()

    var folders: [WatchlistFolder] = []
    var editingFolderID: UUID?
    var customizingFolderID: UUID?
    var showingNewFolderSheet = false
    var activeDragSymbol: WatchlistSymbolDragPayload?
    var folderSortMode: WatchlistFolderSortMode {
        didSet {
            UserDefaults.standard.set(folderSortMode.rawValue, forKey: Self.folderSortModeKey)
            invalidateFolderOrderCache()
        }
    }
    var isLoading = false
    var errorMessage: String?

    private var auth: AuthSession?
    private var debounceTask: Task<Void, Never>?
    private var isPersisting = false
    private var needsSyncAfterPersist = false
    private var hasLoaded = false
    @ObservationIgnored private var cachedPinnedFolderIDs: [UUID]?
    @ObservationIgnored private var cachedRegularFolderIDs: [UUID]?
    @ObservationIgnored private var cachedAllTickers: [String]?
    @ObservationIgnored private var lastQuoteRefresh: Date?
    @ObservationIgnored private var quoteRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var isRefreshingQuotes = false
    private static let folderSortModeKey = "watchlist.folderSortMode"
    private static let legacySymbolSortModeKey = "watchlist.symbolSortMode"
    private static let quoteRefreshInterval: TimeInterval = 45

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
        quoteRefreshTask?.cancel()
        quoteRefreshTask = nil
        isRefreshingQuotes = false
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
        lastQuoteRefresh = nil
        quoteStore.reset()
        invalidateFolderOrderCache()
        invalidateTickerCache()
        ResearchSymbolStorage.clearAll()
    }

    var allTickers: [String] {
        if let cachedAllTickers { return cachedAllTickers }
        let tickers = Array(
            Set(
                folders.flatMap { folder in
                    folder.symbols.map { $0.ticker.uppercased() }
                }
            )
        ).sorted()
        cachedAllTickers = tickers
        return tickers
    }

    var hasSymbols: Bool {
        !allTickers.isEmpty
    }

    func contains(_ symbol: String) -> Bool {
        allTickers.contains(symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    var sortedFolders: [WatchlistFolder] {
        rebuildFolderOrderCacheIfNeeded()
        let ids = (cachedPinnedFolderIDs ?? []) + (cachedRegularFolderIDs ?? [])
        return ids.compactMap { id in folders.first { $0.id == id } }
    }

    var pinnedFolders: [WatchlistFolder] {
        rebuildFolderOrderCacheIfNeeded()
        return (cachedPinnedFolderIDs ?? []).compactMap { id in folders.first { $0.id == id } }
    }

    var regularFolders: [WatchlistFolder] {
        rebuildFolderOrderCacheIfNeeded()
        return (cachedRegularFolderIDs ?? []).compactMap { id in folders.first { $0.id == id } }
    }

    private func rebuildFolderOrderCacheIfNeeded() {
        if cachedPinnedFolderIDs == nil {
            cachedPinnedFolderIDs = sortFolders(folders.filter(\.isPinned)).map(\.id)
        }
        if cachedRegularFolderIDs == nil {
            cachedRegularFolderIDs = sortFolders(folders.filter { !$0.isPinned }).map(\.id)
        }
    }

    private func invalidateFolderOrderCache() {
        cachedPinnedFolderIDs = nil
        cachedRegularFolderIDs = nil
    }

    private func invalidateTickerCache() {
        cachedAllTickers = nil
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
        let quotes = folder.symbols.map { quoteStore.quote(for: $0.id) }
        let total = quotes.reduce(0) { $0 + $1.dayChange }
        let avgPct = quotes.reduce(0) { $0 + $1.dayChangePercent } / Double(quotes.count)
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

        let symbol = WatchlistSymbol(
            id: UUID(),
            ticker: upper,
            companyName: companyName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? upper,
            createdAt: Date()
        )
        folders[index].symbols.append(symbol)
        quoteStore.setZero(for: symbol.id)
        invalidateTickerCache()
        mirrorLocalCache()
        scheduleSync()
    }

    func removeSymbol(_ symbol: String, fromFolderID folderID: UUID) {
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty,
              let index = folders.firstIndex(where: { $0.id == folderID }) else { return }

        let removedIDs = folders[index].symbols.filter { $0.ticker == upper }.map(\.id)
        folders[index].symbols.removeAll { $0.ticker == upper }
        removedIDs.forEach { quoteStore.removeQuote(for: $0) }
        invalidateTickerCache()
        mirrorLocalCache()
        scheduleSync()
    }

    // MARK: - Loading / sync

    func load(localSymbols: [String] = [], includeQuotes: Bool = false) async {
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
            let response = try await WatchlistService.fetchWorkspace(
                accessToken: token,
                includeQuotes: includeQuotes
            )
            applyWorkspace(response, includeQuotes: includeQuotes)

            if includeQuotes {
                lastQuoteRefresh = Date()
            } else if folders.contains(where: { !$0.symbols.isEmpty }) {
                scheduleQuoteRefresh(force: true)
            }

            if folders.isEmpty, !localSymbols.isEmpty, migrating {
                seedFromLocalSymbols(localSymbols)
                await persistWorkspaceImmediately(applyResponse: true)
                if !includeQuotes, folders.contains(where: { !$0.symbols.isEmpty }) {
                    scheduleQuoteRefresh(force: true)
                }
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

    func scheduleQuoteRefresh(force: Bool = false) {
        guard auth?.accessToken != nil else { return }
        quoteRefreshTask?.cancel()
        quoteRefreshTask = Task { [weak self] in
            await self?.refreshQuotesIfNeeded(force: force)
        }
    }

    func refreshQuotesIfNeeded(force: Bool = false) async {
        if !force,
           let lastQuoteRefresh,
           Date().timeIntervalSince(lastQuoteRefresh) < Self.quoteRefreshInterval {
            return
        }
        await refreshQuotes()
    }

    func refreshQuotes() async {
        guard let auth, let token = auth.accessToken else { return }
        guard !isRefreshingQuotes else { return }

        isRefreshingQuotes = true
        defer { isRefreshingQuotes = false }

        do {
            let response = try await WatchlistService.fetchWorkspace(
                accessToken: token,
                includeQuotes: true
            )
            applyQuotes(from: response)
            lastQuoteRefresh = Date()
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
        items.forEach { quoteStore.setZero(for: $0.id) }
        invalidateFolderOrderCache()
        invalidateTickerCache()
        normalizeSortOrders()
    }

    private func applyWorkspace(_ response: WatchlistWorkspaceResponse, includeQuotes: Bool) {
        var mapped = WatchlistAPIMapping.folders(from: response)
        for index in mapped.indices where mapped[index].createdAt == nil {
            mapped[index].createdAt = folders.first(where: { $0.id == mapped[index].id })?.createdAt
        }
        folders = mapped
        if includeQuotes {
            quoteStore.applyWorkspaceQuotes(WatchlistAPIMapping.quotes(from: response))
        } else {
            seedQuotePlaceholders()
        }
        invalidateFolderOrderCache()
        invalidateTickerCache()
        mirrorLocalCache()
    }

    private func seedQuotePlaceholders() {
        var placeholders: [UUID: WatchlistQuote] = [:]
        for symbol in folders.flatMap(\.symbols) {
            placeholders[symbol.id] = .zero
        }
        quoteStore.applyWorkspaceQuotes(placeholders)
    }

    private func applyQuotes(from response: WatchlistWorkspaceResponse) {
        quoteStore.mergeQuotes(WatchlistAPIMapping.quotes(from: response))
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
                applyWorkspace(response, includeQuotes: false)
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
        invalidateFolderOrderCache()
        scheduleSync()
    }

    func renameFolder(id: UUID, name: String, iconName: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        folders[index].iconName = iconName.isEmpty ? WatchlistFolderIcons.defaultIcon : iconName
        scheduleSync()
    }

    func deleteFolder(id: UUID) {
        if let folder = folders.first(where: { $0.id == id }) {
            folder.symbols.forEach { quoteStore.removeQuote(for: $0.id) }
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            folders.removeAll { $0.id == id }
            normalizeSortOrders()
        }
        invalidateFolderOrderCache()
        invalidateTickerCache()
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
        invalidateFolderOrderCache()
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
            invalidateFolderOrderCache()
            scheduleSync()
            return
        }
        dragged.sortOrder = target.sortOrder
        folders.insert(dragged, at: targetIndex)
        normalizeSortOrders()
        invalidateFolderOrderCache()
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
        invalidateFolderOrderCache()
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
        invalidateFolderOrderCache()
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
        invalidateTickerCache()
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
        quoteStore.removeQuote(for: symbolID)
        invalidateTickerCache()
        mirrorLocalCache()
        scheduleSync()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
