import Foundation
import SwiftUI

enum PatternLabelScheme: String, Decodable, Sendable {
    case original3Class = "original_3class"
    case binaryUpdown = "binary_updown"
    case binaryOutperformSpy = "binary_outperform_spy"
    case wideband3Class = "wideband_3class"

    var isBinary: Bool {
        self == .binaryUpdown || self == .binaryOutperformSpy
    }

    var isOutperformSpy: Bool { self == .binaryOutperformSpy }

    static func resolve(_ raw: String?) -> PatternLabelScheme {
        guard let raw, let scheme = PatternLabelScheme(rawValue: raw) else {
            return .original3Class
        }
        return scheme
    }
}

struct PatternPortfolioStrategy: Codable, Sendable {
    let strategyType: String
    let universe: String
    let topN: Int
    let rebalanceDays: Int
    let holdDays: Int
    let maxPositionWeight: Double

    enum CodingKeys: String, CodingKey {
        case strategyType
        case universe
        case portfolioUniverse
        case topN
        case rebalanceDays
        case holdDays
        case maxPositionWeight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strategyType = try container.decode(String.self, forKey: .strategyType)
        if let universeValue = try container.decodeIfPresent(String.self, forKey: .universe) {
            universe = universeValue
        } else {
            universe = try container.decode(String.self, forKey: .portfolioUniverse)
        }
        topN = try container.decode(Int.self, forKey: .topN)
        rebalanceDays = try container.decodeIfPresent(Int.self, forKey: .rebalanceDays) ?? 5
        holdDays = try container.decodeIfPresent(Int.self, forKey: .holdDays) ?? 5
        maxPositionWeight = try container.decodeIfPresent(Double.self, forKey: .maxPositionWeight) ?? 0.15
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategyType, forKey: .strategyType)
        try container.encode(universe, forKey: .universe)
        try container.encode(topN, forKey: .topN)
        try container.encode(rebalanceDays, forKey: .rebalanceDays)
        try container.encode(holdDays, forKey: .holdDays)
        try container.encode(maxPositionWeight, forKey: .maxPositionWeight)
    }
}

enum ModelBenchmark {
    static let symbols: Set<String> = ["SPY"]
    static let notice =
        "This symbol is the Model C benchmark. Excess return vs SPY is always zero here, " +
        "so ranking probabilities are undefined — use pattern, trend, and regime context only."

    static func isBenchmarkSymbol(_ symbol: String?) -> Bool {
        guard let symbol else { return false }
        return symbols.contains(symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    static func filterIndicators(_ indicators: [String: Double]) -> [String: Double] {
        indicators.filter { !$0.key.contains("rs_vs_spy") }
    }
}

enum PatternCandlestickReference {
    private static let descriptions: [String: String] = [
        "hammer":
            "A single candle with a small body near the top and a long lower shadow. Often appears after a decline when sellers were rejected — a potential bullish reversal if confirmed.",
        "doji":
            "Open and close are nearly equal, forming a cross. Signals indecision; the next move depends on context and follow-through.",
        "bullish_engulfing":
            "A large green candle whose body fully covers the prior red candle's body. Buyers overpowered sellers — a potential bullish reversal.",
        "bearish_engulfing":
            "A large red candle whose body fully covers the prior green candle's body. Sellers overpowered buyers — a potential bearish reversal.",
        "morning_star":
            "Three-candle bullish reversal: down candle, small indecision candle, then a strong up candle. Often marks a shift from decline to recovery.",
        "evening_star":
            "Three-candle bearish reversal: up candle, small indecision candle, then a strong down candle. Often marks a shift from advance to weakness.",
        "shooting_star":
            "Small body near the bottom with a long upper shadow after an advance. Buying was rejected at higher prices — a potential bearish reversal.",
        "three_white_soldiers":
            "Three consecutive strong green candles with higher closes. Suggests sustained bullish momentum and buyer control.",
        "three_black_crows":
            "Three consecutive strong red candles with lower closes. Suggests sustained bearish momentum and seller control.",
    ]

    static func description(for patternId: String) -> String? {
        descriptions[patternId]
    }
}

struct PatternTrendForecast: Codable, Sendable {
    let asOfDate: String
    let horizonDays: Int
    let labelScheme: String
    let prediction: Int
    let upProb: Double?
    let rankingScore: Double?
    let tradeSignal: Bool?
    let inTrainingUniverse: Bool
    let probabilities: [String: Double]
    let indicators: [String: Double]
    let modelTrainEndDate: String?
    let modelKey: String?
    let modelLabel: String?
    let trainingUniverse: String?
    let nFeatures: Int?
    let featureGroups: [String]?
    let portfolioStrategy: PatternPortfolioStrategy?
    let isBenchmark: Bool?
    let benchmarkNotice: String?
}

struct PatternTrendForecastDisplay: Sendable {
    let symbol: String?
    let asOfDate: String
    let horizonDays: Int
    let labelScheme: PatternLabelScheme
    let prediction: Int
    let upProb: Double?
    let rankingScore: Double?
    let tradeSignal: Bool?
    let inTrainingUniverse: Bool
    let probabilities: [String: Double]
    let indicators: [String: Double]
    let modelTrainEndDate: String?
    let modelKey: String?
    let modelLabel: String?
    let trainingUniverse: String?
    let nFeatures: Int?
    let featureGroups: [String]
    let portfolioStrategy: PatternPortfolioStrategy?
    let isBenchmark: Bool
    let benchmarkNotice: String

    init(forecast: PatternTrendForecast) {
        symbol = nil
        asOfDate = forecast.asOfDate
        horizonDays = forecast.horizonDays
        labelScheme = PatternLabelScheme.resolve(forecast.labelScheme)
        prediction = forecast.prediction
        upProb = forecast.upProb
        rankingScore = forecast.rankingScore
        tradeSignal = forecast.tradeSignal
        inTrainingUniverse = forecast.inTrainingUniverse
        probabilities = forecast.probabilities
        indicators = forecast.indicators
        modelTrainEndDate = forecast.modelTrainEndDate
        modelKey = forecast.modelKey
        modelLabel = forecast.modelLabel
        trainingUniverse = forecast.trainingUniverse
        nFeatures = forecast.nFeatures
        featureGroups = forecast.featureGroups ?? []
        portfolioStrategy = forecast.portfolioStrategy
        isBenchmark = forecast.isBenchmark == true
        benchmarkNotice = forecast.benchmarkNotice ?? ModelBenchmark.notice
    }

    init(response: PatternPredictionResponse) {
        symbol = response.symbol
        asOfDate = response.asOfDate
        horizonDays = response.horizonDays ?? 5
        labelScheme = response.resolvedLabelScheme
        prediction = response.prediction
        upProb = response.upProb
        rankingScore = response.rankingScore
        tradeSignal = response.tradeSignal
        inTrainingUniverse = response.inTrainingUniverse ?? true
        probabilities = response.probabilities
        indicators = response.indicators
        modelTrainEndDate = response.modelTrainEndDate
        modelKey = response.modelKey
        modelLabel = response.modelLabel
        trainingUniverse = response.trainingUniverse ?? response.modelUniverse
        nFeatures = response.nFeatures
        featureGroups = response.featureGroups ?? []
        portfolioStrategy = response.portfolioStrategy
        isBenchmark =
            response.isBenchmark == true ||
            ModelBenchmark.isBenchmarkSymbol(response.symbol)
        benchmarkNotice = response.benchmarkNotice ?? ModelBenchmark.notice
    }

    var resolvedIndicators: [String: Double] {
        isBenchmark ? ModelBenchmark.filterIndicators(indicators) : indicators
    }

    var usesRankingPortfolio: Bool {
        portfolioStrategy?.strategyType == "ranking"
    }

    var resolvedRankingScore: Double? {
        rankingScore ?? upProb
    }

    var predictedClassLabel: String {
        directionTitle
    }

    var predictedClassProbability: Double? {
        probabilityRows.first(where: \.isSelected)?.value ?? upProb
    }

    var directionTitle: String {
        if labelScheme.isOutperformSpy {
            return prediction == 1 ? "Outperform SPY" : "Underperform SPY"
        }
        if labelScheme.isBinary {
            return prediction == 1 ? "Up" : "Down"
        }
        switch prediction {
        case 1: return "Bullish"
        case -1: return "Bearish"
        default: return "Neutral"
        }
    }

    var directionSubtitle: String {
        if labelScheme.isOutperformSpy {
            return prediction == 1
                ? "Model expects this name to beat SPY over the next 5 trading days."
                : "Model expects this name to lag SPY over the next 5 trading days."
        }
        if labelScheme.isBinary {
            return prediction == 1
                ? "Model expects a positive move over the next 5 trading days."
                : "Model expects a negative move over the next 5 trading days."
        }
        switch prediction {
        case 1:
            return "Model expects a move above +0.5% over the next 5 sessions."
        case -1:
            return "Model expects a move below −0.5% over the next 5 sessions."
        default:
            return "Model expects a flat move within ±0.5% over the next 5 sessions."
        }
    }

    var accentColor: Color {
        if labelScheme.isBinary {
            return prediction == 1 ? AppColors.success : AppColors.error
        }
        switch prediction {
        case 1: return AppColors.success
        case -1: return AppColors.error
        default: return AppColors.warning
        }
    }

    var systemImage: String {
        if labelScheme.isBinary {
            return prediction == 1
                ? "arrow.up.right.circle.fill"
                : "arrow.down.right.circle.fill"
        }
        switch prediction {
        case 1: return "arrow.up.right.circle.fill"
        case -1: return "arrow.down.right.circle.fill"
        default: return "minus.circle.fill"
        }
    }

    private var binaryClassLabels: (down: String, up: String) {
        if labelScheme.isOutperformSpy {
            return ("Underperform SPY", "Outperform SPY")
        }
        return ("Down", "Up")
    }

    var probabilityRows: [(label: String, key: String, value: Double, isSelected: Bool)] {
        if labelScheme.isBinary {
            let labels = binaryClassLabels
            return [
                (
                    labels.down,
                    "0",
                    probabilities["0"] ?? (prediction == 0 ? 1 - (upProb ?? 0) : 0),
                    prediction == 0
                ),
                (
                    labels.up,
                    "1",
                    probabilities["1"] ?? upProb ?? 0,
                    prediction == 1
                ),
            ]
        }
        return [
            ("Down", "-1", probabilities["-1"] ?? 0, prediction == -1),
            ("Flat", "0", probabilities["0"] ?? 0, prediction == 0),
            ("Up", "1", probabilities["1"] ?? 0, prediction == 1),
        ]
    }

    var upProbLabel: String {
        labelScheme.isOutperformSpy ? "P(outperform SPY)" : "P(up)"
    }

    var upProbChipLabel: String {
        labelScheme.isOutperformSpy ? "P vs SPY" : "P(up)"
    }

    var rankingBadgeLabel: String? {
        if usesRankingPortfolio {
            guard let score = resolvedRankingScore else { return nil }
            if score >= 0.65 { return "Top-tier rank" }
            if score >= 0.5 { return "Mid rank" }
            return "Lower rank"
        }
        return tradeSignalLabel
    }

    var rankingBadgeColor: Color {
        if usesRankingPortfolio {
            guard let score = resolvedRankingScore else { return AppColors.secondaryLabel }
            if score >= 0.65 { return AppColors.success }
            if score >= 0.5 { return AppColors.secondaryLabel }
            return AppColors.warning
        }
        return tradeSignalColor
    }

    var portfolioSummary: String? {
        guard let strategy = portfolioStrategy else { return nil }
        let universe = strategy.universe.uppercased()
        return "Ranking portfolio · \(universe) · top \(strategy.topN) · \(strategy.rebalanceDays)d rebalance"
    }

    var modelSummary: String? {
        if let modelLabel, let modelKey {
            let featureCount = nFeatures.map { " · \($0) features" } ?? ""
            return "Model \(modelKey) · \(modelLabel)\(featureCount)"
        }
        return modelLabel
    }

    var tradeSignalLabel: String? {
        guard let tradeSignal else { return nil }
        return tradeSignal ? "Trade signal" : "Below threshold"
    }

    var tradeSignalColor: Color {
        tradeSignal == true ? AppColors.success : AppColors.warning
    }
}

struct PatternPredictionResponse: Decodable, Sendable {
    let symbol: String
    let asOfDate: String
    let horizonDays: Int?
    let labelScheme: String?
    let prediction: Int
    let probabilities: [String: Double]
    let indicators: [String: Double]
    let upProb: Double?
    let rankingScore: Double?
    let tradeSignal: Bool?
    let minUpProb: Double?
    let inTrainingUniverse: Bool?
    let modelTrainEndDate: String?
    let modelUniverse: String?
    let modelKey: String?
    let modelLabel: String?
    let trainingUniverse: String?
    let nFeatures: Int?
    let featureGroups: [String]?
    let portfolioStrategy: PatternPortfolioStrategy?
    let isBenchmark: Bool?
    let benchmarkNotice: String?

    var resolvedLabelScheme: PatternLabelScheme {
        PatternLabelScheme.resolve(labelScheme)
    }

    var display: PatternTrendForecastDisplay {
        PatternTrendForecastDisplay(response: self)
    }
}

struct PatternPredictionHealthResponse: Decodable, Sendable {
    let status: String
    let model: PatternPredictionModelMeta
}

struct PatternPredictionModelMeta: Decodable, Sendable {
    let trainEndDate: String?
    let trainStartDate: String?
    let nFeatures: Int?
    let symbols: [String]?
    let labelScheme: String?
    let useClassWeights: Bool?
    let minUpProb: Double?
    let universe: String?
    let modelKey: String?
    let modelLabel: String?
    let featureGroups: [String]?
    let portfolioStrategy: PatternPortfolioStrategy?
}

// MARK: - Pattern Intelligence

enum PatternAlignmentState: String, Decodable, Sendable {
    case confirmed
    case conflict
    case modelOnly = "model_only"

    init(rawOrConfidence alignment: String, confidence: String) {
        if let parsed = PatternAlignmentState(rawValue: alignment) {
            self = parsed
            return
        }
        if confidence == "conflicting" {
            self = .conflict
        } else {
            self = .modelOnly
        }
    }
}

struct PrimaryCandlestickPattern: Codable, Sendable {
    let patternId: String
    let label: String
    let direction: String
    let strength: Double
    let asOfDate: String
}

struct PatternTrendContextIntel: Codable, Sendable {
    let asOfDate: String
    let close: Double
    let sma50: Double?
    let sma200: Double?
    let aboveSma50: Bool?
    let aboveSma200: Bool?
    let trendBias: String
    let rsVsSpy21d: Double?
    let rsVsSpy63d: Double?
    let rsVsSpy126d: Double?
    let volRatio20d: Double?
    let volZscore20d: Double?
}

struct PatternIntelligenceScores: Codable, Sendable {
    let patternStrength: Double
    let trendStrength: Double
    let relativeStrength: Double
    let volumeConfirmation: Double
    let modelAlignment: Double
    let confirmationScore: Double
    let confidence: String
    let alignmentState: String?
}

struct PatternSetupOutcome: Codable, Sendable {
    let label: String
    let patternLabel: String
    let trendLabel: String
    let rsLabel: String
    let occurrenceCount: Int
    let patternOnlyCount: Int
    let avgReturn5d: Double?
    let avgReturn20d: Double?
    let winRate5d: Double?
    let winRate20d: Double?
    let maxDrawdown20d: Double?

    var hasStats: Bool {
        occurrenceCount >= 3 && avgReturn5d != nil
    }
}

struct PatternExplanation: Codable, Sendable {
    let headline: String
    let patternSummary: String
    let trendContext: String
    let historicalContext: String
    let modelContext: String
    let confidenceExplanation: String
    let disclaimer: String
}

struct ChartAnalystOutlook: Codable, Sendable {
    let label: String
    let tone: String
    let probability: Double?
    let probabilityDisplay: String?
    let expectation: String
    let modelContext: String?
    let isBenchmark: Bool?
    let benchmarkNotice: String?

    var headline: String {
        label
    }
}

struct ChartAnalystKeyLevel: Codable, Sendable {
    let label: String
    let price: Double?
    let levelType: String?
    let display: String
    let implication: String
    let available: Bool?

    var isActionable: Bool {
        available != false && price != nil
    }
}

struct ChartAnalystEvidenceBullet: Codable, Sendable {
    let text: String
    let tone: String
}

struct ChartAnalystSummary: Codable, Sendable {
    let outlook: ChartAnalystOutlook
    let keyLevel: ChartAnalystKeyLevel
    let whyThisOutlook: [ChartAnalystEvidenceBullet]
    let thesis: String
    let disclaimer: String
}

struct ChartIntelligencePoint: Codable, Sendable {
    let date: String
    let price: Double
}

struct ChartIntelligenceTrendline: Codable, Sendable {
    let label: String?
    let style: String?
    let ratio: Double?
    let startDate: String?
    let endDate: String?
    let startPrice: Double?
    let endPrice: Double?
    let points: [ChartIntelligencePoint]?
}

struct ChartIntelligenceZone: Codable, Sendable {
    let priceLow: Double?
    let priceHigh: Double?
    let label: String?
    let zoneType: String?
    let touches: Int?
    let strength: Double?

    private enum CodingKeys: String, CodingKey {
        case priceLow, priceHigh, label, zoneType, touches, strength
        case price_low, price_high, zone_type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        priceLow = try container.decodeIfPresent(Double.self, forKey: .priceLow)
            ?? container.decodeIfPresent(Double.self, forKey: .price_low)
        priceHigh = try container.decodeIfPresent(Double.self, forKey: .priceHigh)
            ?? container.decodeIfPresent(Double.self, forKey: .price_high)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        zoneType = try container.decodeIfPresent(String.self, forKey: .zoneType)
            ?? container.decodeIfPresent(String.self, forKey: .zone_type)
        touches = try container.decodeIfPresent(Int.self, forKey: .touches)
        strength = try container.decodeIfPresent(Double.self, forKey: .strength)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(priceLow, forKey: .priceLow)
        try container.encodeIfPresent(priceHigh, forKey: .priceHigh)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(zoneType, forKey: .zoneType)
        try container.encodeIfPresent(touches, forKey: .touches)
        try container.encodeIfPresent(strength, forKey: .strength)
    }
}

struct ChartIntelligenceBreakoutEvent: Codable, Sendable {
    let kind: String
    let barIndex: Int?
    let date: String?
    let price: Double?
    let zoneLabel: String?
    let label: String?
    let volumeRatio: Double?
}

struct ChartIntelligenceFibChannel: Codable, Sendable {
    let bias: String?
    let summary: String?
    let lines: [ChartIntelligenceTrendline]?
}

struct ChartIntelligencePayload: Codable, Sendable {
    let trendlines: [ChartIntelligenceTrendline]?
    let supportZones: [ChartIntelligenceZone]?
    let resistanceZones: [ChartIntelligenceZone]?
    let annotations: [ChartIntelligenceAnnotation]?
    let breakoutEvents: [ChartIntelligenceBreakoutEvent]?
    let fibChannel: ChartIntelligenceFibChannel?
    let summary: ChartAnalystSummary?

    var hasAnalystSummary: Bool {
        guard let label = summary?.outlook.label else { return false }
        return !label.isEmpty
    }

    var hasOverlays: Bool {
        !(supportZones ?? []).isEmpty
            || !(resistanceZones ?? []).isEmpty
            || !(trendlines ?? []).isEmpty
            || !(breakoutEvents ?? []).isEmpty
            || fibChannel?.lines?.isEmpty == false
    }
}

struct ChartIntelligenceAnnotation: Codable, Sendable {
    let type: String?
    let breakoutKind: String?
    let barIndex: Int?
    let date: String?
    let price: Double?
    let label: String?
    let direction: String?
    let position: String?
}

struct PatternIntelligenceResponse: Codable, Sendable {
    let symbol: String
    let asOfDate: String
    let primaryPattern: PrimaryCandlestickPattern?
    let activePatterns: [PrimaryCandlestickPattern]?
    let trendContext: PatternTrendContextIntel
    let scores: PatternIntelligenceScores
    let historicalStats: PatternHistoricalStats?
    let setupOutcome: PatternSetupOutcome?
    let explanation: PatternExplanation
    let chartIntelligence: ChartIntelligencePayload?
    let isBenchmark: Bool?

    var display: PatternIntelligenceDisplay {
        PatternIntelligenceDisplay(response: self)
    }
}

struct PatternHistoricalStats: Codable, Sendable {
    let patternId: String
    let label: String
    let occurrenceCount: Int
    let avgReturn5d: Double?
    let avgReturn20d: Double?
    let winRate5d: Double?
    let winRate20d: Double?
    let maxDrawdown20d: Double?
}

struct PatternIntelligenceDisplay: Sendable {
    let symbol: String
    let asOfDate: String
    let primaryPattern: PrimaryCandlestickPattern?
    let trendContext: PatternTrendContextIntel
    let scores: PatternIntelligenceScores
    let setupOutcome: PatternSetupOutcome?
    let explanation: PatternExplanation
    let chartIntelligence: ChartIntelligencePayload?
    let analystSummary: ChartAnalystSummary?
    let alignment: PatternAlignmentState
    let isBenchmark: Bool
    let benchmarkNotice: String

    init(response: PatternIntelligenceResponse) {
        symbol = response.symbol
        asOfDate = response.asOfDate
        primaryPattern = response.primaryPattern
        trendContext = response.trendContext
        scores = response.scores
        setupOutcome = response.setupOutcome
        explanation = response.explanation
        chartIntelligence = response.chartIntelligence
        analystSummary = response.chartIntelligence?.summary
        alignment = PatternAlignmentState(
            rawOrConfidence: response.scores.alignmentState ?? "",
            confidence: response.scores.confidence
        )
        isBenchmark =
            response.isBenchmark == true ||
            response.chartIntelligence?.summary?.outlook.isBenchmark == true ||
            ModelBenchmark.isBenchmarkSymbol(response.symbol)
        benchmarkNotice =
            response.chartIntelligence?.summary?.outlook.benchmarkNotice ??
            ModelBenchmark.notice
    }

    var verdict: String {
        analystSummary?.thesis ?? explanation.confidenceExplanation
    }

    var verdictColor: Color {
        if let tone = analystSummary?.outlook.tone {
            switch tone {
            case "strong_bullish", "bullish", "slight_bullish":
                return AppColors.success
            case "strong_bearish", "bearish", "slight_bearish":
                return AppColors.danger
            case "warning":
                return AppColors.warning
            default:
                break
            }
        }

        if alignment == .conflict {
            return AppColors.warning
        }

        return AppColors.secondaryLabel
    }
}
