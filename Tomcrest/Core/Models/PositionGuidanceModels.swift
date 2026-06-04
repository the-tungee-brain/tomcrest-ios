import Foundation

enum SymbolThesis: String, Decodable {
    case bullish = "BULLISH"
    case neutral = "NEUTRAL"
    case bearish = "BEARISH"
}

enum PositionKind: String, Decodable {
    case equityLong = "EQUITY_LONG"
    case longCall = "LONG_CALL"
    case longPut = "LONG_PUT"
    case shortCall = "SHORT_CALL"
    case shortPut = "SHORT_PUT"
}

enum GuidanceConfidence: String, Decodable {
    case low
    case medium
    case high
}

struct GuidanceDriver: Decodable {
    let code: String
    let label: String
    let points: Double
    let detail: String?
}

struct ScoringContributor: Decodable {
    let bucket: String
    let points: Double
    let label: String
    let driverCode: String?
}

struct SymbolThesisBlock: Decodable {
    let thesis: SymbolThesis
    let summary: String
    let tradeQualityScore: Int?
    let regimeId: String?
}

struct PositionGuidanceItem: Decodable, Identifiable {
    var id: String { positionKey }
    let positionKey: String
    let positionKind: PositionKind
    let displayLabel: String
    let instrumentSymbol: String
    let underlyingSymbol: String
    let putCall: String?
    let strike: Double?
    let expiration: String?
    let quantity: Double
    let marketValue: Double
    let openProfitLossPct: Double?
    let verdict: String
    let confidence: GuidanceConfidence
    let urgency: Int
    let relativeRiskRank: Int?
    let crossLegSanity: Bool?
    let primaryDriver: GuidanceDriver?
    let secondaryDriver: GuidanceDriver?
    let tertiaryDriver: GuidanceDriver?
    let justification: String
    let primaryReason: String
    let supportingFactors: [String]
    let riskFactors: [String]
    let scoringContributors: [ScoringContributor]?

    var effectiveScoringContributors: [ScoringContributor] {
        scoringContributors ?? []
    }
}

struct SymbolPositionGuidance: Decodable {
    let symbol: String
    let asOfDate: String?
    let hasPositions: Bool
    let thesis: SymbolThesisBlock?
    let positions: [PositionGuidanceItem]
    let synthesisNarrative: String?
    let analysisPrompt: String?
    let disclaimer: String?
    let dataGaps: [String]?
    let scoringTrace: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case asOfDate
        case hasPositions
        case thesis
        case positions
        case synthesisNarrative
        case analysisPrompt
        case disclaimer
        case dataGaps
        case scoringTrace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        asOfDate = try container.decodeIfPresent(String.self, forKey: .asOfDate)
        hasPositions = try container.decodeIfPresent(Bool.self, forKey: .hasPositions) ?? false
        thesis = try container.decodeIfPresent(SymbolThesisBlock.self, forKey: .thesis)
        positions = try container.decodeIfPresent([PositionGuidanceItem].self, forKey: .positions) ?? []
        synthesisNarrative = try container.decodeIfPresent(String.self, forKey: .synthesisNarrative)
        analysisPrompt = try container.decodeIfPresent(String.self, forKey: .analysisPrompt)
        disclaimer = try container.decodeIfPresent(String.self, forKey: .disclaimer)
        dataGaps = try container.decodeIfPresent([String].self, forKey: .dataGaps)
        scoringTrace = try container.decodeIfPresent(String.self, forKey: .scoringTrace)
    }
}

struct PortfolioExitAttentionItem: Decodable, Identifiable {
    var id: String { positionKey }
    let positionKey: String
    let symbol: String
    let positionKind: PositionKind
    let displayLabel: String
    let verdict: String
    let confidence: GuidanceConfidence
    let urgency: Int
    let primaryReason: String
}

struct PortfolioExitAttentionResponse: Decodable {
    let items: [PortfolioExitAttentionItem]
}
