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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        datetime = try container.decodeIfPresent(String.self, forKey: .datetime) ?? ""
        headline = try container.decode(String.self, forKey: .headline)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        originalSummary = try container.decodeIfPresent(String.self, forKey: .originalSummary) ?? ""
        sentiment = try container.decodeIfPresent(String.self, forKey: .sentiment) ?? "neutral"
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? headline
        topics = try container.decodeIfPresent([String].self, forKey: .topics) ?? []
        url = try container.decodeIfPresent(String.self, forKey: .url)
        image = try container.decodeIfPresent(String.self, forKey: .image)
    }

    private enum CodingKeys: String, CodingKey {
        case id, datetime, headline, source, sentiment, confidence, summary, topics, url, image, originalSummary
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        overallSentiment = try container.decodeIfPresent(String.self, forKey: .overallSentiment) ?? "neutral"
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        insights = try container.decodeIfPresent([String].self, forKey: .insights) ?? []
        risks = try container.decodeIfPresent([String].self, forKey: .risks) ?? []
        dominantDriver = try container.decodeIfPresent(String.self, forKey: .dominantDriver)
        marketImpactHorizon = try container.decodeIfPresent(String.self, forKey: .marketImpactHorizon)
        actionabilityScore = try container.decodeIfPresent(Int.self, forKey: .actionabilityScore)
        investorTakeaway = try container.decodeIfPresent(String.self, forKey: .investorTakeaway)
        deepAnalysis = try container.decodeIfPresent(String.self, forKey: .deepAnalysis)
        items = try container.decodeIfPresent([EnrichedNewsItem].self, forKey: .items) ?? []
        aiEnrichment = try container.decodeIfPresent(Bool.self, forKey: .aiEnrichment) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case symbol, summary, insights, risks, items
        case overallSentiment, dominantDriver, marketImpactHorizon, actionabilityScore
        case investorTakeaway, deepAnalysis, aiEnrichment
    }

    var hasAiAnalysis: Bool { aiEnrichment }
}
