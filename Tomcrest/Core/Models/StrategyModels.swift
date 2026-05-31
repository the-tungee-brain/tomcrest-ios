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
    let onboardingCompletedAt: String?
}

struct UserInvestmentProfileUpdate: Encodable {
    let primaryStrategy: String?
    let riskTolerance: String?
    let optionsExperience: String?
    let incomeVsGrowth: String?
    let wheel: WheelStrategyConfigUpdate?
    let dividend: DividendStrategyConfigUpdate?
    let etfCore: EtfCoreStrategyConfigUpdate?
    let completeOnboarding: Bool?

    init(
        primaryStrategy: String? = nil,
        riskTolerance: String? = nil,
        optionsExperience: String? = nil,
        incomeVsGrowth: String? = nil,
        wheel: WheelStrategyConfigUpdate? = nil,
        dividend: DividendStrategyConfigUpdate? = nil,
        etfCore: EtfCoreStrategyConfigUpdate? = nil,
        completeOnboarding: Bool? = nil
    ) {
        self.primaryStrategy = primaryStrategy
        self.riskTolerance = riskTolerance
        self.optionsExperience = optionsExperience
        self.incomeVsGrowth = incomeVsGrowth
        self.wheel = wheel
        self.dividend = dividend
        self.etfCore = etfCore
        self.completeOnboarding = completeOnboarding
    }
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

struct StrategyReadiness: Decodable {
    let schwabLinked: Bool
    let hasPositions: Bool
    let cashAvailable: Double?
    let approvedSymbols: [String]?
}

struct StrategyNextAction: Decodable, Identifiable {
    let type: String
    let title: String
    let reason: String
    let symbol: String?
    let actionId: String?

    var id: String {
        actionId ?? "\(type)-\(symbol ?? title)"
    }
}

struct StrategySymbolStatus: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let held: Bool
    let portfolioWeightPct: Double?
    let wheelPhase: String?
    let statusLabel: String
    let nextAction: StrategyNextAction?
    let priority: Int?
}

struct StrategyRecommendations: Decodable {
    let strategy: String
    let currentStep: JourneyStep?
    let wheelPhase: String?
    let readiness: StrategyReadiness
    let symbol: String?
    let symbolStatuses: [StrategySymbolStatus]?
    let nextActions: [StrategyNextAction]
    let screenerSummary: String?
}

enum StrategyFormSupport {
    static let riskOptions = ["conservative", "moderate", "aggressive"]
    static let optionsExperienceOptions = ["none", "beginner", "intermediate", "advanced"]
    static let incomeVsGrowthOptions = ["income", "balanced", "growth"]
    static let wheelLikeStrategies: Set<String> = ["wheel", "csp-income", "covered-call"]

    struct EditorForm {
        var strategyId: String
        var riskTolerance: String
        var optionsExperience: String
        var incomeVsGrowth: String
        var symbols: [String]
        var etfPrimary: String
        var etfBond: String
        var etfStockPct: Double
        var rebalanceThresholdPct: Double
        var targetDeltaMin: Double
        var targetDeltaMax: Double
        var preferredDteDays: Int
        var maxSingleNamePct: Double
    }

    static func deltaBandDescription(for riskTolerance: String) -> String {
        let band = deltaBand(for: riskTolerance)
        return String(format: "%.2f–%.2f delta", band.min, band.max)
    }

    static func editorForm(from profile: UserInvestmentProfile?, strategyId: String?) -> EditorForm {
        let strategy = strategyId ?? profile?.primaryStrategy ?? "wheel"
        let risk = profile?.riskTolerance ?? "moderate"
        let delta = deltaBand(for: risk)
        let allocation = profile?.etfCore?.targetAllocation ?? [:]
        let entries = Array(allocation.sorted { $0.key < $1.key })
        let primary = entries.first?.key ?? "VTI"
        let bond = entries.dropFirst().first?.key ?? "BND"
        let stockPct = entries.first?.value ?? 70

        return EditorForm(
            strategyId: strategy,
            riskTolerance: risk,
            optionsExperience: profile?.optionsExperience ?? "beginner",
            incomeVsGrowth: profile?.incomeVsGrowth ?? "balanced",
            symbols: symbols(from: profile),
            etfPrimary: primary,
            etfBond: bond,
            etfStockPct: stockPct,
            rebalanceThresholdPct: profile?.etfCore?.rebalanceThresholdPct ?? 5,
            targetDeltaMin: profile?.wheel?.targetDeltaMin ?? delta.min,
            targetDeltaMax: profile?.wheel?.targetDeltaMax ?? delta.max,
            preferredDteDays: profile?.wheel?.preferredDteDays ?? 7,
            maxSingleNamePct: profile?.wheel?.maxSingleNamePct ?? 15
        )
    }

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

    static func buildUpdate(form: EditorForm, profile: UserInvestmentProfile?) -> UserInvestmentProfileUpdate {
        let delta = deltaBand(for: form.riskTolerance)
        let deltaMin = wheelLikeStrategies.contains(form.strategyId) ? form.targetDeltaMin : delta.min
        let deltaMax = wheelLikeStrategies.contains(form.strategyId) ? form.targetDeltaMax : delta.max

        var wheel: WheelStrategyConfigUpdate?
        var dividend: DividendStrategyConfigUpdate?
        var etfCore: EtfCoreStrategyConfigUpdate?

        if wheelLikeStrategies.contains(form.strategyId) {
            wheel = WheelStrategyConfigUpdate(
                wheelSymbols: form.symbols,
                targetDeltaMin: deltaMin,
                targetDeltaMax: deltaMax,
                preferredDteDays: form.preferredDteDays,
                maxSingleNamePct: form.maxSingleNamePct
            )
        } else if form.strategyId == "dividend" {
            dividend = DividendStrategyConfigUpdate(
                dividendSymbols: form.symbols,
                targetYieldPct: profile?.dividend?.targetYieldPct,
                maxPayoutRatio: profile?.dividend?.maxPayoutRatio ?? 75
            )
        } else if form.strategyId == "etf-core" {
            let bondPct = max(0, min(100, 100 - form.etfStockPct))
            etfCore = EtfCoreStrategyConfigUpdate(
                targetAllocation: [
                    form.etfPrimary.uppercased(): form.etfStockPct,
                    form.etfBond.uppercased(): bondPct,
                ],
                rebalanceThresholdPct: form.rebalanceThresholdPct
            )
        }

        return UserInvestmentProfileUpdate(
            primaryStrategy: form.strategyId,
            riskTolerance: form.riskTolerance,
            optionsExperience: form.optionsExperience,
            incomeVsGrowth: form.incomeVsGrowth,
            wheel: wheel,
            dividend: dividend,
            etfCore: etfCore,
            completeOnboarding: nil
        )
    }

    static func buildUpdate(form: EditorForm) -> UserInvestmentProfileUpdate {
        buildUpdate(form: form, profile: nil)
    }

    static func buildUpdate(
        strategyId: String,
        riskTolerance: String,
        symbols: [String],
        profile: UserInvestmentProfile?
    ) -> UserInvestmentProfileUpdate {
        var form = editorForm(from: profile, strategyId: strategyId)
        form.riskTolerance = riskTolerance
        form.symbols = symbols
        return buildUpdate(form: form)
    }

    static func parseSymbols(_ text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
    }
}
