import Foundation

struct TickerSymbolItem: Codable, Identifiable, Hashable {
    var id: String { symbol }
    let symbol: String
    let title: String?
    let assetType: String?
    let logoURL: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case title
        case assetType
        case logoURL = "logoUrl"
    }
}

struct ResearchSnapshot: Codable {
    let symbol: String
    let name: String
    let sector: String
    let country: String
    let price: Double
    let changePct: Double
    let marketCap: String
    let range52w: String?
    let logo: String?
    let weburl: String?
    let dividendYieldPct: Double?
    let peRatio: Double?
    let expenseRatioPct: Double?
}

struct PerformanceSnapshot: Codable {
    let oneMonth: String
    let threeMonth: String
    let oneYear: String
    let trendLabel: String
    let volatilityNote: String
}

struct SymbolIntelligence: Codable {
    let symbol: String
    let signals: [IntelligenceSignal]
    let partial: Bool?
}

struct ResearchOverviewBundle: Decodable {
    let symbol: String
    let assetType: String?
    let asOf: String
    let snapshot: ResearchSnapshot
    let performance: PerformanceSnapshot
    let intelligence: SymbolIntelligence
    let summary: AISummary?
    let streetAnalysis: StreetAnalysisSnapshot?
    let etfHoldings: EtfHoldingsContext?
    let etfFunds: EtfFundsSnapshot?
}

struct AISummary: Codable {
    let short: String
    let long: String
    let sentiment: String
    let investmentThesis: String
    let keyStrengths: [String]
    let keyRisks: [String]
    let whatToWatch: [String]
    let valuationContext: String
}

enum AssetTypeLabel {
    static func display(_ assetType: String?) -> String {
        switch assetType?.uppercased() {
        case "ETF": "ETF"
        case "MUTUAL_FUND": "Mutual fund"
        case "INDEX": "Index"
        case "STOCK": "Stock"
        case "ADR": "ADR"
        case "CRYPTO": "Crypto"
        default: assetType ?? "Symbol"
        }
    }
}
