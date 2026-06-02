import Foundation

enum PatternPredictionService {
    static func fetchHealth(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> PatternPredictionHealthResponse {
        try await api.get("/pattern/health", accessToken: accessToken)
    }

    static func fetchPrediction(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> PatternPredictionResponse {
        try await api.get(
            "/pattern/predict",
            query: ["symbol": symbol.uppercased()],
            accessToken: accessToken
        )
    }

    static func fetchIntelligence(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> PatternIntelligenceResponse {
        try await api.get(
            "/pattern/intelligence",
            query: ["symbol": symbol.uppercased()],
            accessToken: accessToken
        )
    }
}
