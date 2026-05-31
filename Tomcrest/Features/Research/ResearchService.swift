import Foundation

enum ResearchService {
    static func searchSymbols(
        query: String,
        accessToken: String,
        limit: Int = 10,
        api: APIClient = .shared
    ) async throws -> [TickerSymbolItem] {
        try await api.get(
            "/symbols/search",
            query: [
                "q": query.uppercased(),
                "limit": String(limit),
            ],
            accessToken: accessToken
        )
    }

    static func fetchOverviewBundle(
        symbol: String,
        accessToken: String,
        holdingsLimit: Int = 8,
        api: APIClient = .shared
    ) async throws -> ResearchOverviewBundle {
        try await api.get(
            "/research/overview-bundle",
            query: [
                "symbol": symbol.uppercased(),
                "holdings_limit": String(holdingsLimit),
            ],
            accessToken: accessToken
        )
    }

    static func streamResearchChat(
        symbol: String,
        prompt: String,
        accessToken: String,
        model: String = ChatConfig.defaultModel,
        chatSessionId: String? = nil,
        newChatSession: Bool = false,
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> StreamCompletion {
        let bodyData = try ResearchChatPayloadBuilder.buildBody(
            symbol: symbol,
            prompt: prompt,
            model: model,
            chatSessionId: chatSessionId,
            newChatSession: newChatSession
        )
        return try await StreamingAPIClient.streamPost(
            path: "/research/chat",
            bodyData: bodyData,
            accessToken: accessToken,
            onChunk: onChunk
        )
    }

    static func fetchEarningsList(
        symbol: String,
        limit: Int = 8,
        api: APIClient = .shared
    ) async throws -> EarningsListResponse {
        try await api.get(
            "/research/earnings",
            query: [
                "symbol": symbol.uppercased(),
                "limit": String(limit),
            ]
        )
    }

    static func fetchEarningsDetail(
        symbol: String,
        reportDate: String,
        accessToken: String,
        includeAnalysis: Bool = true,
        includeTranscript: Bool = true,
        api: APIClient = .shared
    ) async throws -> EarningsDetailResponse {
        try await api.get(
            "/research/earnings/detail",
            query: [
                "symbol": symbol.uppercased(),
                "report_date": String(reportDate.prefix(10)),
                "include_transcript": includeTranscript ? "true" : "false",
                "include_analysis": includeAnalysis ? "true" : "false",
            ],
            accessToken: accessToken
        )
    }

    static func fetchPressReleases(
        symbol: String,
        accessToken: String,
        lookbackDays: Int = 90,
        api: APIClient = .shared
    ) async throws -> PressReleasesResponse {
        try await api.get(
            "/research/press-releases",
            query: [
                "symbol": symbol.uppercased(),
                "lookback_days": String(lookbackDays),
            ],
            accessToken: accessToken
        )
    }

    static func fetchDividendHistory(
        symbol: String,
        accessToken: String,
        shares: Double = 100,
        api: APIClient = .shared
    ) async throws -> DividendHistoryContext {
        try await api.get(
            "/research/dividends",
            query: [
                "symbol": symbol.uppercased(),
                "shares": String(shares),
            ],
            accessToken: accessToken
        )
    }

    static func fetchFundamentals(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> FundamentalsBlock {
        try await api.get(
            "/research/fundamentals",
            query: ["symbol": symbol.uppercased()],
            accessToken: accessToken
        )
    }
}
