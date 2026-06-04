import Foundation

enum SetupStageId: String, Decodable {
    case baseBuilding = "BASE_BUILDING"
    case tightening = "TIGHTENING"
    case breakoutWatch = "BREAKOUT_WATCH"
    case breakoutTriggered = "BREAKOUT_TRIGGERED"
    case extended = "EXTENDED"
}

struct EmergingLeaderItem: Decodable, Identifiable {
    let rank: Int
    let symbol: String
    let setupQualityScore: Int
    let setupStage: SetupStageId
    let setupStageLabel: String
    let compressionVelocity: Int
    let compressionVelocityLabel: String
    let whyItRanks: String
    let positiveFactors: [String]
    let missingFactors: [String]
    let nextConfirmation: [String]

    var id: String { symbol }
}

struct EmergingLeadersResponse: Decodable {
    let asOfDate: String?
    let timestamp: String
    let universeScanned: Int
    let symbolsWithData: Int
    let evaluationsComputed: Int
    let excludedTopMovers: Int
    let items: [EmergingLeaderItem]
}
