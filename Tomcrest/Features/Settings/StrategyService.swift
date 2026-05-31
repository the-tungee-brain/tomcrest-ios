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

    static func fetchRecommendations(
        strategyId: String,
        accessToken: String,
        symbol: String? = nil,
        api: APIClient = .shared
    ) async throws -> StrategyRecommendations? {
        var path = "/strategies/\(strategyId)/recommendations"
        if let symbol, !symbol.isEmpty {
            let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
            path += "?symbol=\(encoded)"
        }
        return try await api.get(path, accessToken: accessToken)
    }

    static func streamPlaybookAsk(
        action: StrategyNextAction,
        strategyId: String,
        accessToken: String,
        model: String = ChatConfig.defaultModel,
        chatSessionId: String? = nil,
        newChatSession: Bool = true,
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> StreamCompletion {
        let symbol = action.symbol?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let body = PlaybookAskRequest(
            symbol: symbol,
            actionType: action.type,
            actionTitle: action.title,
            actionReason: action.reason,
            strategy: strategyId,
            model: model,
            newChatSession: newChatSession,
            chatSessionId: chatSessionId
        )
        let bodyData = try JSONEncoder().encode(body)
        return try await StreamingAPIClient.streamPost(
            path: "/strategy/playbook/ask",
            bodyData: bodyData,
            accessToken: accessToken,
            onChunk: onChunk
        )
    }

    static func fetchStockScreener(
        strategyId: String,
        accessToken: String,
        page: Int = 1,
        pageSize: Int = 10,
        filters: StrategyScreenerFilters = StrategyScreenerFilters(),
        api: APIClient = .shared
    ) async throws -> StrategyStockScreenerResult {
        var query: [String: String] = [
            "page": String(page),
            "pageSize": String(pageSize),
        ]
        for (key, value) in filters.queryItems {
            query[key] = value
        }
        return try await api.get(
            "/strategies/\(strategyId)/stock-screener",
            query: query,
            accessToken: accessToken
        )
    }
}

private struct PlaybookAskRequest: Encodable {
    let symbol: String
    let actionType: String
    let actionTitle: String
    let actionReason: String
    let strategy: String
    let model: String
    let newChatSession: Bool
    let chatSessionId: String?
}
