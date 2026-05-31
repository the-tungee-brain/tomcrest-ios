import Foundation

enum StrategyService {
    static func fetchCatalog(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> [StrategyCatalogItem] {
        try await api.get("/strategies", accessToken: accessToken)
    }

    static func fetchProfile(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> UserInvestmentProfile? {
        try await api.get("/user/investment-profile", accessToken: accessToken)
    }

    static func updateProfile(
        _ update: UserInvestmentProfileUpdate,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> UserInvestmentProfile {
        try await api.put("/user/investment-profile", body: update, accessToken: accessToken)
    }

    static func selectStrategy(
        _ strategyId: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> UserStrategyJourney {
        struct SelectResponse: Decodable {
            let journey: UserStrategyJourney
        }
        let response: SelectResponse = try await api.postNoBody(
            "/strategies/\(strategyId)/select",
            accessToken: accessToken
        )
        return response.journey
    }

    static func fetchJourney(
        strategyId: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> UserStrategyJourney? {
        try await api.get("/strategies/\(strategyId)/journey", accessToken: accessToken)
    }

    static func updateJourneyStep(
        strategyId: String,
        stepId: String,
        status: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> UserStrategyJourney {
        try await api.patch(
            "/strategies/\(strategyId)/journey/steps/\(stepId)",
            body: JourneyStepUpdate(status: status),
            accessToken: accessToken
        )
    }
}
