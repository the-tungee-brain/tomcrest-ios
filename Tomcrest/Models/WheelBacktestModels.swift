import Foundation

struct WheelBacktestTrade: Decodable, Identifiable {
    var id: String { "\(date)-\(action)-\(strike ?? 0)" }
    let date: String
    let action: String
    let label: String?
    let putCall: String?
    let strike: Double?
    let premiumUsd: Double?
    let feesUsd: Double?
    let wheelCycle: Int?
    let note: String?
}

struct WheelBacktestEquityPoint: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let equityUsd: Double
    let cashUsd: Double?
    let sharesHeld: Double?
}

struct WheelBacktestResult: Decodable {
    let symbol: String
    let lookbackYears: Int
    let startDate: String
    let endDate: String
    let totalPlUsd: Double
    let totalReturnPct: Double
    let cagrPct: Double
    let buyAndHoldReturnPct: Double
    let totalPremiumCollectedUsd: Double
    let putAssignments: Int
    let callsAssigned: Int
    let completedWheelCycles: Int
    let trades: [WheelBacktestTrade]
    let equityCurve: [WheelBacktestEquityPoint]
}

struct WheelBacktestQuery {
    var symbol: String
    var years: Int = 5
    var targetDeltaMin: Double = 0.20
    var targetDeltaMax: Double = 0.30
    var dteDays: Int = 30
    var contracts: Int = 1
    var maintainOneLot: Bool = true
    var callStrikeMode: String = "delta"

    var queryItems: [String: String] {
        [
            "symbol": symbol.uppercased(),
            "years": String(years),
            "targetDeltaMin": String(targetDeltaMin),
            "targetDeltaMax": String(targetDeltaMax),
            "dteDays": String(dteDays),
            "contracts": String(contracts),
            "maintainOneLot": maintainOneLot ? "true" : "false",
            "callStrikeMode": callStrikeMode,
        ]
    }
}
