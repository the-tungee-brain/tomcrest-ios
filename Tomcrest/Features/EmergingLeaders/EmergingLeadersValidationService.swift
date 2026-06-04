import Foundation

enum EmergingLeadersValidationService {
    static func fetch(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> EmergingLeadersValidationResponse {
        try await api.get(
            "/research/emerging-leaders-validation",
            accessToken: accessToken
        )
    }
}
