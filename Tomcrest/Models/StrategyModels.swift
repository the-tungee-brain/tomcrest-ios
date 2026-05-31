import Foundation

struct StrategyCatalogItem: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let bestFor: [String]?
    let prerequisites: [String]?
    let stepCount: Int
    let requiresSchwab: Bool
    let requiresOptions: Bool
}

struct WheelStrategyConfig: Decodable {
    let wheelSymbols: [String]?
    let targetDeltaMin: Double?
    let targetDeltaMax: Double?
    let preferredDteDays: Int?
    let maxSingleNamePct: Double?
}

struct DividendStrategyConfig: Decodable {
    let dividendSymbols: [String]?
    let targetYieldPct: Double?
    let maxPayoutRatio: Double?
}

struct EtfCoreStrategyConfig: Decodable {
    let targetAllocation: [String: Double]?
    let rebalanceThresholdPct: Double?
}

struct UserInvestmentProfile: Decodable {
    let userId: String
    let primaryStrategy: String?
    let riskTolerance: String
    let optionsExperience: String
    let incomeVsGrowth: String
    let wheel: WheelStrategyConfig?
    let dividend: DividendStrategyConfig?
    let etfCore: EtfCoreStrategyConfig?
}

struct UserInvestmentProfileUpdate: Encodable {
    let primaryStrategy: String?
    let riskTolerance: String?
    let optionsExperience: String?
    let incomeVsGrowth: String?
    let wheel: WheelStrategyConfigUpdate?
    let dividend: DividendStrategyConfigUpdate?
    let etfCore: EtfCoreStrategyConfigUpdate?
}

struct WheelStrategyConfigUpdate: Encodable {
    let wheelSymbols: [String]
    let targetDeltaMin: Double
    let targetDeltaMax: Double
    let preferredDteDays: Int
    let maxSingleNamePct: Double
}

struct DividendStrategyConfigUpdate: Encodable {
    let dividendSymbols: [String]
    let targetYieldPct: Double?
    let maxPayoutRatio: Double
}

struct EtfCoreStrategyConfigUpdate: Encodable {
    let targetAllocation: [String: Double]
    let rebalanceThresholdPct: Double
}

struct JourneyStep: Decodable, Identifiable {
    var id: String { stepId }
    let stepId: String
    let title: String
    let description: String
    let status: String
    let order: Int
    let completedAt: String?
}

struct UserStrategyJourney: Decodable {
    let userId: String
    let strategy: String
    let currentStepId: String?
    let steps: [JourneyStep]
    let completionPct: Double
    let startedAt: String?
    let completedAt: String?
}

struct JourneyStepUpdate: Encodable {
    let status: String
}

enum StrategyFormSupport {
    static let riskOptions = ["conservative", "moderate", "aggressive"]
    static let wheelLikeStrategies: Set<String> = ["wheel", "csp-income", "covered-call"]

    static func symbols(from profile: UserInvestmentProfile?) -> [String] {
        guard let profile else { return [] }
        if let symbols = profile.wheel?.wheelSymbols, !symbols.isEmpty {
            return symbols
        }
        if let symbols = profile.dividend?.dividendSymbols, !symbols.isEmpty {
            return symbols
        }
        return []
    }

    static func deltaBand(for riskTolerance: String) -> (min: Double, max: Double) {
        switch riskTolerance {
        case "conservative":
            (0.10, 0.15)
        case "aggressive":
            (0.35, 0.50)
        default:
            (0.20, 0.30)
        }
    }

    static func buildUpdate(
        strategyId: String,
        riskTolerance: String,
        symbols: [String],
        profile: UserInvestmentProfile?
    ) -> UserInvestmentProfileUpdate {
        let delta = deltaBand(for: riskTolerance)
        let optionsExperience = profile?.optionsExperience ?? "beginner"
        let incomeVsGrowth = profile?.incomeVsGrowth ?? "balanced"

        var wheel: WheelStrategyConfigUpdate?
        var dividend: DividendStrategyConfigUpdate?
        var etfCore: EtfCoreStrategyConfigUpdate?

        if wheelLikeStrategies.contains(strategyId) {
            wheel = WheelStrategyConfigUpdate(
                wheelSymbols: symbols,
                targetDeltaMin: delta.min,
                targetDeltaMax: delta.max,
                preferredDteDays: profile?.wheel?.preferredDteDays ?? 7,
                maxSingleNamePct: profile?.wheel?.maxSingleNamePct ?? 15
            )
        } else if strategyId == "dividend" {
            dividend = DividendStrategyConfigUpdate(
                dividendSymbols: symbols,
                targetYieldPct: profile?.dividend?.targetYieldPct,
                maxPayoutRatio: profile?.dividend?.maxPayoutRatio ?? 75
            )
        } else if strategyId == "etf-core" {
            etfCore = EtfCoreStrategyConfigUpdate(
                targetAllocation: profile?.etfCore?.targetAllocation ?? ["VTI": 70, "BND": 30],
                rebalanceThresholdPct: profile?.etfCore?.rebalanceThresholdPct ?? 5
            )
        }

        return UserInvestmentProfileUpdate(
            primaryStrategy: strategyId,
            riskTolerance: riskTolerance,
            optionsExperience: optionsExperience,
            incomeVsGrowth: incomeVsGrowth,
            wheel: wheel,
            dividend: dividend,
            etfCore: etfCore
        )
    }

    static func parseSymbols(_ text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
    }
}
