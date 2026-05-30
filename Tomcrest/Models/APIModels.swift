import Foundation

enum SignalSeverity: String, Codable {
    case info
    case watch
    case warning
    case critical
}

struct IntelligenceSignal: Codable, Identifiable {
    var id: String { "\(kind)-\(message)" }
    let kind: String
    let severity: SignalSeverity
    let message: String
    let symbol: String?
}

struct ProactiveAlert: Codable, Identifiable {
    var id: String { action }
    let action: String
    let label: String
    let reason: String
    let priority: Int
    let symbol: String?
}

struct PortfolioIntelligence: Codable {
    let signals: [IntelligenceSignal]
    let alerts: [ProactiveAlert]
}

struct MorningBrief: Codable {
    let headline: String?
    let summary: String?
    let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case headline
        case summary
        case generatedAt = "generated_at"
    }
}

struct SymbolSearchResult: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String?
    let assetType: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case name
        case assetType = "asset_type"
    }
}

struct SymbolSearchResponse: Decodable {
    let results: [SymbolSearchResult]
}

struct AccountPlanResponse: Decodable {
    let plan: String?
    let features: [String: Bool]?
}
