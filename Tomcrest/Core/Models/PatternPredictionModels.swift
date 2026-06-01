import Foundation

enum TrendSignal: Int, CaseIterable, Sendable {
    case bearish = -1
    case neutral = 0
    case bullish = 1

    init(prediction: Int) {
        self = TrendSignal(rawValue: prediction) ?? .neutral
    }

    var title: String {
        switch self {
        case .bearish: "Bearish"
        case .neutral: "Neutral"
        case .bullish: "Bullish"
        }
    }

    var subtitle: String {
        switch self {
        case .bearish: "Model expects a move below −0.5% over the next 5 sessions"
        case .neutral: "Model expects a flat move within ±0.5% over the next 5 sessions"
        case .bullish: "Model expects a move above +0.5% over the next 5 sessions"
        }
    }

    var probabilityLabel: String {
        switch self {
        case .bearish: "Down"
        case .neutral: "Flat"
        case .bullish: "Up"
        }
    }

    var probabilityKey: String {
        String(rawValue)
    }
}

struct PatternPredictionResponse: Decodable, Sendable {
    let symbol: String
    let date: String
    let prediction: Int
    let probabilities: [String: Double]
    let indicators: [String: Double]

    var signal: TrendSignal {
        TrendSignal(prediction: prediction)
    }

    func probability(for signal: TrendSignal) -> Double {
        probabilities[signal.probabilityKey] ?? 0
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
}
