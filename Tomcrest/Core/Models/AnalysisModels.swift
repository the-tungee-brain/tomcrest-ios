import Foundation

struct StructuredAnalysisAction: Decodable {
    let title: String
    let reason: String
    let symbol: String?
}

struct StructuredAnalysisSection: Decodable, Identifiable {
    var id: String { slug }
    private let slug: String

    let title: String
    let body: String?
    let bullets: [String]?

    enum CodingKeys: String, CodingKey {
        case slug = "id"
        case title
        case body
        case bullets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        bullets = try container.decodeIfPresent([String].self, forKey: .bullets)
        slug = (try container.decodeIfPresent(String.self, forKey: .slug)) ?? title
    }
}

struct StructuredAnalysis: Decodable {
    let summary: String
    let recommendedAction: StructuredAnalysisAction?
    let sections: [StructuredAnalysisSection]

    func filteringSections(_ isIncluded: (StructuredAnalysisSection) -> Bool) -> StructuredAnalysis {
        .init(
            summary: summary,
            recommendedAction: recommendedAction,
            sections: sections.filter(isIncluded)
        )
    }

    private init(summary: String, recommendedAction: StructuredAnalysisAction?, sections: [StructuredAnalysisSection]) {
        self.summary = summary
        self.recommendedAction = recommendedAction
        self.sections = sections
    }
}

struct CashMapStep: Decodable, Identifiable {
    var id: Int { step }
    let step: Int
    let label: String
    let amount: Double?
    let isSubtraction: Bool?
}

struct PortfolioCashMap: Decodable {
    let steps: [CashMapStep]
    let deployableCash: Double
    let trimProceeds: Double?
    let totalToRedeploy: Double
    let minCashBufferPct: Double?
}

struct PortfolioConcentrationMetrics: Decodable {
    let liquidationValue: Double
    let cash: Double
    let cashPct: Double
    let cspReserved: Double
    let cashAfterCsp: Double
    let minCashBuffer: Double
    let deployableCash: Double
    let distinctSymbols: Int
    let effectiveNames: Int
    let top1Pct: Double
    let top3Pct: Double
    let top5Pct: Double
    let singleNameLimitPct: Double
}

struct HoldingAllocationReview: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let weightPct: Double
    let marketValue: Double
    let cspReservedCash: Double?
    let portfolioSpending: Double?
    let spendingWeightPct: Double?
    let status: String
    let actionSummary: String
}

struct TrimPlanItem: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let currentWeightPct: Double
    let targetWeightPct: Double
    let trimDollars: Double
}

struct DeployPlanItem: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let deployDollars: Double
    let note: String?
}

struct PortfolioAnalysisPrecomputed: Decodable {
    let concentration: PortfolioConcentrationMetrics
    let cashMap: PortfolioCashMap
    let holdings: [HoldingAllocationReview]
    let trimPlan: [TrimPlanItem]
    let deployPlan: [DeployPlanItem]
    let totalTrimProceeds: Double
}

struct ComparePathOption: Decodable, Identifiable {
    var id: String { path }
    let path: String
    let title: String
    let lines: [String]
}

struct HeldOptionOutcomes: Decodable, Identifiable {
    var id: String { "\(currentLeg.strike)-\(currentLeg.expiration)" }
    let currentLeg: OptionLegOutcome
    let comparePaths: [ComparePathOption]
    let roll: RollPathOutcome?
    let close: ClosePathOutcome?
    let hold: HoldPathOutcome?
    let drivers: HeldOptionDecisionDrivers?
}

struct OptionLegOutcome: Decodable {
    let putCall: String?
    let side: String?
    let strike: Double
    let expiration: String
    let contracts: Double?
    let daysToExpiration: Int?
    let delta: Double?
    let mark: Double?
}

struct RollPathOutcome: Decodable {
    let closeLeg: OptionLegOutcome
    let openLeg: OptionLegOutcome
    let netCreditPerContract: Double?
    let isNetCredit: Bool
    let cashPicture: RollCashPicture?
}

struct RollCashPicture: Decodable {
    let summary: String?
    let rollNetPerContract: Double?
    let netCashAfterRollPerContract: Double?
}

struct ClosePathOutcome: Decodable {
    let costPerContract: Double?
    let openPnl: Double?
}

struct HoldPathOutcome: Decodable {
    let daysToExpiration: Int?
    let delta: Double?
    let assignmentNote: String?
}

struct HeldOptionDecisionDrivers: Decodable {
    let portfolioWeightPct: Double?
    let openPnl: Double?
    let openPnlPct: Double?
    let actionTrigger: String?
}

struct SymbolAnalysisPrecomputed: Decodable {
    let symbol: String
    let underlyingPrice: Double?
    let heldOptionOutcomes: [HeldOptionOutcomes]

    enum CodingKeys: String, CodingKey {
        case symbol
        case underlyingPrice
        case heldOptionOutcomes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        underlyingPrice = try container.decodeIfPresent(Double.self, forKey: .underlyingPrice)
        heldOptionOutcomes = try container.decodeIfPresent([HeldOptionOutcomes].self, forKey: .heldOptionOutcomes) ?? []
    }
}

struct StructuredAnalyzeResponse {
    let analysis: StructuredAnalysis?
    let portfolioPrecomputed: PortfolioAnalysisPrecomputed?
    let symbolPrecomputed: SymbolAnalysisPrecomputed?

    init(
        analysis: StructuredAnalysis?,
        portfolioPrecomputed: PortfolioAnalysisPrecomputed?,
        symbolPrecomputed: SymbolAnalysisPrecomputed? = nil
    ) {
        self.analysis = analysis
        self.portfolioPrecomputed = portfolioPrecomputed
        self.symbolPrecomputed = symbolPrecomputed
    }
}
