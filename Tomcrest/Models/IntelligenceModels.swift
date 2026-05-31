import Foundation

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
    let optionsScorecard: OptionsScorecard?
    let optionChainPreview: OptionChainPreview?
    let rollSuggestions: [OptionRollSuggestion]?
    let partial: Bool?
    let reauthRequired: Bool?
}

enum SymbolOptionsHelpers {
    static func hasOptionsContent(_ intelligence: SymbolIntelligenceDetail?) -> Bool {
        guard let intelligence else { return false }
        if intelligence.optionsScorecard != nil { return true }
        if intelligence.optionChainPreview != nil { return true }
        if !(intelligence.rollSuggestions ?? []).isEmpty { return true }
        return false
    }

    static func symbolHasOptionPositions(_ positions: [Position]) -> Bool {
        positions.contains { $0.instrument.assetType == "OPTION" }
    }
}
