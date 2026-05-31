import Foundation

enum ResearchSymbolStorage {
    private static let watchlistKey = "tomcrest-watchlist"
    private static let recentKey = "tomcrest-recent-symbols"
    private static let researchChatUsedKey = "tomcrest-research-chat-used"
    private static let maxRecent = 8

    static func watchlist() -> [String] {
        readSymbols(key: watchlistKey).sorted()
    }

    static func isWatchlisted(_ symbol: String) -> Bool {
        let upper = normalize(symbol)
        return watchlist().contains(upper)
    }

    @discardableResult
    static func toggleWatchlist(_ symbol: String) -> Bool {
        let upper = normalize(symbol)
        guard !upper.isEmpty else { return false }

        var symbols = watchlist()
        if let index = symbols.firstIndex(of: upper) {
            symbols.remove(at: index)
            writeSymbols(symbols, key: watchlistKey)
            return false
        }

        symbols.append(upper)
        writeSymbols(Array(Set(symbols)).sorted(), key: watchlistKey)
        return true
    }

    static func removeFromWatchlist(_ symbol: String) {
        let upper = normalize(symbol)
        guard !upper.isEmpty else { return }

        var symbols = watchlist()
        symbols.removeAll { $0 == upper }
        writeSymbols(symbols, key: watchlistKey)
    }

    static func recentSymbols() -> [String] {
        readSymbols(key: recentKey)
    }

    static func addRecent(_ symbol: String) {
        let upper = normalize(symbol)
        guard !upper.isEmpty else { return }

        let next = [upper] + recentSymbols().filter { $0 != upper }
        writeSymbols(Array(next.prefix(maxRecent)), key: recentKey)
    }

    static func clearRecent() {
        writeSymbols([], key: recentKey)
    }

    static func markResearchChatUsed() {
        UserDefaults.standard.set(true, forKey: researchChatUsedKey)
    }

    static func hasUsedResearchChat() -> Bool {
        UserDefaults.standard.bool(forKey: researchChatUsedKey)
    }

    private static func normalize(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func readSymbols(key: String) -> [String] {
        guard let raw = UserDefaults.standard.array(forKey: key) as? [String] else {
            return []
        }
        return raw.map(normalize).filter { !$0.isEmpty }
    }

    private static func writeSymbols(_ symbols: [String], key: String) {
        UserDefaults.standard.set(symbols, forKey: key)
    }
}

@MainActor
@Observable
final class ResearchSymbolBookmarks {
    private(set) var watchlist: [String] = []
    private(set) var recentSymbols: [String] = []

    init() {
        reload()
    }

    func reload() {
        watchlist = ResearchSymbolStorage.watchlist()
        recentSymbols = ResearchSymbolStorage.recentSymbols()
    }

    func isWatchlisted(_ symbol: String) -> Bool {
        let upper = Self.normalize(symbol)
        guard !upper.isEmpty else { return false }
        return watchlist.contains(upper)
    }

    @discardableResult
    func toggleWatchlist(_ symbol: String) -> Bool {
        let added = ResearchSymbolStorage.toggleWatchlist(symbol)
        reload()
        return added
    }

    func removeFromWatchlist(_ symbol: String) {
        ResearchSymbolStorage.removeFromWatchlist(symbol)
        reload()
    }

    func recordRecent(_ symbol: String) {
        ResearchSymbolStorage.addRecent(symbol)
        reload()
    }

    func clearRecent() {
        ResearchSymbolStorage.clearRecent()
        reload()
    }

    var recentWithoutWatchlist: [String] {
        let watchlistSet = Set(watchlist)
        return recentSymbols.filter { !watchlistSet.contains($0) }
    }

    var hasQuickAccess: Bool {
        !watchlist.isEmpty || !recentWithoutWatchlist.isEmpty
    }

    private static func normalize(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
