import Foundation
import SwiftUI

enum PatternLabelScheme: String, Decodable, Sendable {
    case original3Class = "original_3class"
    case binaryUpdown = "binary_updown"
    case wideband3Class = "wideband_3class"

    var isBinary: Bool { self == .binaryUpdown }

    static func resolve(_ raw: String?) -> PatternLabelScheme {
        guard let raw, let scheme = PatternLabelScheme(rawValue: raw) else {
            return .original3Class
        }
        return scheme
    }
}

struct PatternTrendForecast: Codable, Sendable {
    let asOfDate: String
    let horizonDays: Int
    let labelScheme: String
    let prediction: Int
    let upProb: Double?
    let tradeSignal: Bool?
    let inTrainingUniverse: Bool
    let probabilities: [String: Double]
    let indicators: [String: Double]
    let modelTrainEndDate: String?
}

struct PatternTrendForecastDisplay: Sendable {
    let asOfDate: String
    let horizonDays: Int
    let labelScheme: PatternLabelScheme
    let prediction: Int
    let upProb: Double?
    let tradeSignal: Bool?
    let inTrainingUniverse: Bool
    let probabilities: [String: Double]
    let indicators: [String: Double]
    let modelTrainEndDate: String?

    init(forecast: PatternTrendForecast) {
        asOfDate = forecast.asOfDate
        horizonDays = forecast.horizonDays
        labelScheme = PatternLabelScheme.resolve(forecast.labelScheme)
        prediction = forecast.prediction
        upProb = forecast.upProb
        tradeSignal = forecast.tradeSignal
        inTrainingUniverse = forecast.inTrainingUniverse
        probabilities = forecast.probabilities
        indicators = forecast.indicators
        modelTrainEndDate = forecast.modelTrainEndDate
    }

    init(response: PatternPredictionResponse) {
        asOfDate = response.date
        horizonDays = 5
        labelScheme = response.resolvedLabelScheme
        prediction = response.prediction
        upProb = response.upProb
        tradeSignal = response.tradeSignal
        inTrainingUniverse = response.inTrainingUniverse ?? true
        probabilities = response.probabilities
        indicators = response.indicators
        modelTrainEndDate = response.modelTrainEndDate
    }

    var directionTitle: String {
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

    var probabilityRows: [(label: String, key: String, value: Double, isSelected: Bool)] {
        if labelScheme.isBinary {
            return [
                (
                    "Down",
                    "0",
                    probabilities["0"] ?? (prediction == 0 ? 1 - (upProb ?? 0) : 0),
                    prediction == 0
                ),
                (
                    "Up",
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
    let date: String
    let labelScheme: String?
    let prediction: Int
    let probabilities: [String: Double]
    let indicators: [String: Double]
    let upProb: Double?
    let tradeSignal: Bool?
    let minUpProb: Double?
    let inTrainingUniverse: Bool?
    let modelTrainEndDate: String?
    let modelUniverse: String?

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
}
