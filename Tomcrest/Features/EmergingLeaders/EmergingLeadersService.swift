import Foundation

enum EmergingLeadersService {
    static func fetch(
        accessToken: String,
        limit: Int = 20,
        api: APIClient = .shared
    ) async throws -> EmergingLeadersResponse {
        try await api.get(
            "/research/emerging-leaders",
            query: ["limit": String(limit)],
            accessToken: accessToken,
            sessionKind: .longRunning
        )
    }
}
