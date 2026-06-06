import Foundation

struct PeerMetric: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String?
    let oneYearReturn: String?
    let peTrailing: String?
}

struct PeerComparison: Decodable {
    let targetSymbol: String?
    let targetOneYearReturn: String?
    let targetPeTrailing: String?
    let peers: [PeerMetric]?
    let summary: String?
}

struct CachedResearchSnippet: Decodable {
    let generatedAt: String?
    let sentiment: String?
    let short: String?
    let investmentThesis: String?
    let keyStrengths: [String]?
    let keyRisks: [String]?
    let whatToWatch: [String]?
    let valuationContext: String?
}

struct OptionsStrikeCandidate: Decodable, Identifiable {
    var id: String { "\(side)-\(strike)-\(expiration)" }
    let side: String
    let strike: Double
    let expiration: String
    let delta: Double?
    let openInterest: Double?
    let bid: Double?
    let ask: Double?
    let lastPrice: Double?
    let mark: Double?
    let score: Double
    let rationale: String
}

struct OptionsScorecard: Decodable {
    let underlyingPrice: Double?
    let coveredCallCandidates: [OptionsStrikeCandidate]?
    let cspCandidates: [OptionsStrikeCandidate]?
    let assignmentFlags: [String]?

    var calls: [OptionsStrikeCandidate] { coveredCallCandidates ?? [] }
    var puts: [OptionsStrikeCandidate] { cspCandidates ?? [] }
    var flags: [String] { assignmentFlags ?? [] }
}

struct OptionChainSideQuote: Decodable {
    let bid: Double?
    let ask: Double?
    let mark: Double?
    let lastPrice: Double?
    let delta: Double?
    let theta: Double?
    let openInterest: Double?
    let iv: Double?
}

struct OptionChainTableRow: Decodable, Identifiable {
    var id: Double { strike }
    let strike: Double
    let call: OptionChainSideQuote?
    let put: OptionChainSideQuote?
}

struct OptionChainPreview: Decodable {
    let expiration: String?
    let strikeCount: Int?
    let underlyingPrice: Double?
    let rows: [OptionChainTableRow]
}

struct OptionRollSuggestion: Decodable, Identifiable {
    var id: String { "\(side)-\(currentStrike)-\(currentExpiration)" }
    let side: String
    let currentStrike: Double
    let currentExpiration: String
    let suggestedStrike: Double
    let suggestedExpiration: String
    let currentDelta: Double?
    let suggestedDelta: Double?
    let estimatedCredit: Double?
    let rationale: String
    let action: String
}

struct SymbolIntelligenceDetail: Decodable {
    let symbol: String
    let signals: [IntelligenceSignal]
    let peerComparison: PeerComparison?
    let eventTimeline: [EventTimelineEntry]?
    let optionsScorecard: OptionsScorecard?
    let optionChainPreview: OptionChainPreview?
    let rollSuggestions: [OptionRollSuggestion]?
    let cachedResearch: CachedResearchSnippet?
    let patternForecast: PatternTrendForecast?
    let patternIntelligence: PatternIntelligenceResponse?
    let dataGaps: [String]?
    let partial: Bool?
    let reauthRequired: Bool?
    let authorizationUrl: String?
}

enum SymbolOptionsHelpers {
    static func hasOptionsContent(_ intelligence: SymbolIntelligenceDetail?) -> Bool {
        guard let intelligence else { return false }
        if !(intelligence.optionsScorecard?.calls ?? []).isEmpty { return true }
        if !(intelligence.optionsScorecard?.puts ?? []).isEmpty { return true }
        if !(intelligence.optionsScorecard?.flags ?? []).isEmpty { return true }
        if !(intelligence.optionChainPreview?.rows ?? []).isEmpty { return true }
        if !(intelligence.rollSuggestions ?? []).isEmpty { return true }
        return false
    }

    static func symbolHasOptionPositions(_ positions: [Position]) -> Bool {
        positions.contains { $0.instrument.assetType == "OPTION" }
    }

    static func shouldShowOptionsContent(
        positions: [Position],
        intelligence: SymbolIntelligenceDetail?
    ) -> Bool {
        symbolHasOptionPositions(positions) || hasOptionsContent(intelligence)
    }
}
