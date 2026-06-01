import Foundation

struct WatchlistQuote: Equatable {
    var price: Double
    var dayChange: Double
    var dayChangePercent: Double

    static let zero = WatchlistQuote(price: 0, dayChange: 0, dayChangePercent: 0)
}

@MainActor
@Observable
final class WatchlistQuoteStore {
    private(set) var quotesBySymbolID: [UUID: WatchlistQuote] = [:]

    func quote(for id: UUID) -> WatchlistQuote {
        quotesBySymbolID[id] ?? .zero
    }

    func applyWorkspaceQuotes(_ quotes: [UUID: WatchlistQuote]) {
        quotesBySymbolID = quotes
    }

    func mergeQuotes(_ quotes: [UUID: WatchlistQuote]) {
        guard !quotes.isEmpty else { return }
        for (id, quote) in quotes {
            quotesBySymbolID[id] = quote
        }
    }

    func setZero(for id: UUID) {
        quotesBySymbolID[id] = .zero
    }

    func removeQuote(for id: UUID) {
        quotesBySymbolID.removeValue(forKey: id)
    }

    func reset() {
        quotesBySymbolID = [:]
    }
}
