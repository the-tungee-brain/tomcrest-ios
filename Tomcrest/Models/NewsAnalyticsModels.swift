import Foundation

struct EnrichedNewsItem: Decodable, Identifiable {
    let id: Int
    let datetime: String
    let headline: String
    let source: String
    let originalSummary: String
    let sentiment: String
    let confidence: Double
    let summary: String
    let topics: [String]
    let url: String?
    let image: String?

    enum CodingKeys: String, CodingKey {
        case id, datetime, headline, source, sentiment, confidence, summary, topics, url, image
        case originalSummary = "original_summary"
    }
}

struct StockNewsView: Decodable {
    let symbol: String
    let overallSentiment: String
    let summary: String
    let insights: [String]
    let risks: [String]
    let dominantDriver: String?
    let marketImpactHorizon: String?
    let actionabilityScore: Int?
    let investorTakeaway: String?
    let deepAnalysis: String?
    let items: [EnrichedNewsItem]
    let aiEnrichment: Bool

    enum CodingKeys: String, CodingKey {
        case symbol, summary, insights, risks, items
        case overallSentiment = "overall_sentiment"
        case dominantDriver = "dominant_driver"
        case marketImpactHorizon = "market_impact_horizon"
        case actionabilityScore = "actionability_score"
        case investorTakeaway
        case deepAnalysis
        case aiEnrichment
    }

    var hasAiAnalysis: Bool { aiEnrichment }
}
