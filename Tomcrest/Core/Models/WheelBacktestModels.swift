import Foundation

struct WheelBacktestCycle: Decodable, Identifiable {
    var id: Int { cycle }
    let cycle: Int
    let putStrike: Double?
    let stockEntryDate: String?
    let callStrike: Double?
    let stockExitDate: String?
    let stockRoundTripPlUsd: Double?
    let completed: Bool?
}

struct WheelBacktestAnnualRow: Decodable, Identifiable {
    var id: Int { year }
    let year: Int
    let startEquityUsd: Double?
    let endEquityUsd: Double?
    let plUsd: Double?
    let returnPct: Double?
    let premiumUsd: Double?
    let feesUsd: Double?
}

struct WheelBacktestTrade: Decodable, Identifiable {
    var id: String { "\(date)-\(action)-\(strike ?? 0)-\(wheelCycle ?? 0)" }
    let date: String
    let action: String
    let label: String?
    let putCall: String?
    let strike: Double?
    let premiumUsd: Double?
    let feesUsd: Double?
    let wheelCycle: Int?
    let cycleMonth: String?
    let cashFlowUsd: Double?
    let note: String?
}

struct WheelBacktestEquityPoint: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let equityUsd: Double
    let cashUsd: Double?
    let sharesHeld: Double?
    let phase: String?
    let stockCloseUsd: Double?
    let buyAndHoldEquityUsd: Double?

    enum CodingKeys: String, CodingKey {
        case date, equityUsd, cashUsd, phase, stockCloseUsd, buyAndHoldEquityUsd
        case sharesHeld = "shares"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        equityUsd = try container.decode(Double.self, forKey: .equityUsd)
        cashUsd = try container.decodeIfPresent(Double.self, forKey: .cashUsd)
        phase = try container.decodeIfPresent(String.self, forKey: .phase)
        stockCloseUsd = try container.decodeIfPresent(Double.self, forKey: .stockCloseUsd)
        buyAndHoldEquityUsd = try container.decodeIfPresent(Double.self, forKey: .buyAndHoldEquityUsd)
        if let shares = try? container.decodeIfPresent(Int.self, forKey: .sharesHeld) {
            sharesHeld = Double(shares)
        } else {
            sharesHeld = try container.decodeIfPresent(Double.self, forKey: .sharesHeld)
        }
    }
}

struct WheelBacktestResult: Decodable {
    let symbol: String
    let lookbackYears: Int
    let startDate: String
    let endDate: String
    let totalPlUsd: Double
    let totalReturnPct: Double
    let cagrPct: Double?
    let buyAndHoldReturnPct: Double
    let totalPremiumCollectedUsd: Double
    let putAssignments: Int
    let callsAssigned: Int
    let completedWheelCycles: Int
    let trades: [WheelBacktestTrade]
    let equityCurve: [WheelBacktestEquityPoint]
    let wheelCycles: [WheelBacktestCycle]?
    let annualSummary: [WheelBacktestAnnualRow]?
    let assumptions: [String]?
    let startingCashUsd: Double?
    let endingEquityUsd: Double?
}

struct WheelBacktestQuery: Equatable {
    var symbol: String
    var years: Int = 5
    var targetDeltaMin: Double = 0.20
    var targetDeltaMax: Double = 0.30
    var dteDays: Int = 30
    var contracts: Int = 1
    var maintainOneLot: Bool = true
    var callStrikeMode: String = "delta"

    static let allowedDteDays: Set<Int> = [7, 14, 30, 90]

    static func normalizeDteDays(_ days: Int) -> Int {
        if allowedDteDays.contains(days) { return days }
        switch days {
        case 5: return 7
        case 10: return 14
        case 21: return 14
        case 45: return 30
        case 63: return 90
        default: return 30
        }
    }

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

enum WheelBacktestGrouping {
    static func tradesByCycle(_ trades: [WheelBacktestTrade]) -> [(cycle: Int, trades: [WheelBacktestTrade])] {
        let grouped = Dictionary(grouping: trades) { $0.wheelCycle ?? 0 }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }
}
