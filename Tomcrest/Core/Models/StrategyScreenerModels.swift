import Foundation

struct ScreenerPresetSummary: Decodable {
    let id: String
    let label: String
    let description: String
}

struct StrategyScreenerQuote: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let companyName: String?
    let sector: String?
    let marketCap: Double?
    let peRatio: Double?
    let dividendYield: Double?
    let price: Double?
    let presetFit: Bool?
}

struct StrategyStockScreenerResult: Decodable {
    let strategy: String
    let preset: ScreenerPresetSummary
    let quotes: [StrategyScreenerQuote]
    let pinnedQuotes: [StrategyScreenerQuote]?
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let summary: String
    let generatedAt: String?
}

struct StrategyScreenerFilters {
    var minMarketCap: Int = 2_000_000_000
    var maxPe: Double?
    var requireDividend = false
    var minDividendYield: Double?
    var sectors: [String]?

    var queryItems: [String: String] {
        var items: [String: String] = [
            "minMarketCap": String(minMarketCap),
            "requireDividend": requireDividend ? "true" : "false",
        ]
        if let maxPe { items["maxPe"] = String(maxPe) }
        if let minDividendYield { items["minDividendYield"] = String(minDividendYield) }
        if let sectors, !sectors.isEmpty { items["sectors"] = sectors.joined(separator: ",") }
        return items
    }
}
