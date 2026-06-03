import Foundation

enum TradeEnvironment: String, Decodable {
    case favorable = "FAVORABLE"
    case neutral = "NEUTRAL"
    case avoid = "AVOID"
}

enum ScoreBucket: String, Decodable {
    case trade = "TRADE"
    case setup = "SETUP"
    case watchlist = "WATCHLIST"
    case noTrade = "NO_TRADE"
}

enum TradeVerdict: String, Decodable {
    case trade = "TRADE"
    case watchlist = "WATCHLIST"
    case noTrade = "NO_TRADE"
}

enum TradeAction: String, Decodable {
    case enter = "ENTER"
    case waitForSetup = "WAIT_FOR_SETUP"
    case avoid = "AVOID"
}

struct TradeDecisionRegime: Decodable {
    let regimeId: String?
    let tradeEnvironment: TradeEnvironment
}

struct TradeDecisionReasonBreakdown: Decodable {
    let hardBlockers: [String]
    let primaryWeakness: String?
    let secondaryFactors: [String]
}

struct TradeDecision: Decodable {
    let symbol: String
    let asOfDate: String?
    let regime: TradeDecisionRegime
    let tradeQualityScore: Int
    let scoreBucket: ScoreBucket
    let verdict: TradeVerdict
    let action: TradeAction
    let reasonBreakdown: TradeDecisionReasonBreakdown
}
