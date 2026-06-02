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
}

struct PatternTrendForecastDisplay: Sendable {
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

    init(forecast: PatternTrendForecast) {
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
    }

    init(response: PatternPredictionResponse) {
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
    }

    var usesRankingPortfolio: Bool {
        portfolioStrategy?.strategyType == "ranking"
    }

    var resolvedRankingScore: Double? {
        rankingScore ?? upProb
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
