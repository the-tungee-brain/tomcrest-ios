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
        includeSummary: Bool = false,
        api: APIClient = .shared
    ) async throws -> ResearchOverviewBundle {
        try await api.get(
            "/research/overview-bundle",
            query: [
                "symbol": symbol.uppercased(),
                "holdings_limit": String(holdingsLimit),
                "include_summary": includeSummary ? "true" : "false",
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchStockChart(
        symbol: String,
        accessToken: String,
        period: String = "3mo",
        interval: String = "1d",
        api: APIClient = .shared
    ) async throws -> StockChartPayload {
        try await api.get(
            "/get-stock-data",
            query: [
                "symbol": symbol.uppercased(),
                "period": period,
                "interval": interval,
            ],
            accessToken: accessToken
        )
    }

    static func fetchSecFilings(
        symbol: String,
        accessToken: String,
        limit: Int = 12,
        api: APIClient = .shared
    ) async throws -> SecFilingsResponse {
        try await api.get(
            "/research/sec/filings",
            query: [
                "symbol": symbol.uppercased(),
                "limit": String(limit),
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchSecFinancials(
        symbol: String,
        accessToken: String,
        period: String = "annual",
        limit: Int = 8,
        api: APIClient = .shared
    ) async throws -> SecFinancialsResponse {
        try await api.get(
            "/research/sec/financials",
            query: [
                "symbol": symbol.uppercased(),
                "period": period,
                "limit": String(limit),
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchSecRatios(
        symbol: String,
        accessToken: String,
        period: String = "annual",
        limit: Int = 8,
        api: APIClient = .shared
    ) async throws -> SecRatiosResponse {
        try await api.get(
            "/research/sec/ratios",
            query: [
                "symbol": symbol.uppercased(),
                "period": period,
                "limit": String(limit),
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
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
        accessToken: String,
        limit: Int = 8,
        api: APIClient = .shared
    ) async throws -> EarningsListResponse {
        try await api.get(
            "/research/earnings",
            query: [
                "symbol": symbol.uppercased(),
                "limit": String(limit),
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchEarningsDetail(
        symbol: String,
        reportDate: String,
        accessToken: String,
        includeAnalysis: Bool = false,
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
            accessToken: accessToken,
            keyDecoding: .camelCase
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
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchDividendHistory(
        symbol: String,
        accessToken: String,
        shares: Double = 100,
        investmentUsd: Double? = nil,
        sharePrice: Double? = nil,
        projectYears: Int? = nil,
        reinvestDividends: Bool = false,
        priceCagrPct: Double? = nil,
        dividendCagrPct: Double? = nil,
        historyStartYear: Int? = nil,
        annualContributionUsd: Double = 0,
        api: APIClient = .shared
    ) async throws -> DividendHistoryContext {
        var query: [String: String?] = [
            "symbol": symbol.uppercased(),
            "shares": String(shares),
            "reinvest_dividends": reinvestDividends ? "true" : "false",
            "annual_contribution_usd": String(annualContributionUsd),
        ]
        if let projectYears { query["project_years"] = String(projectYears) }
        if let priceCagrPct { query["price_cagr_pct"] = String(priceCagrPct) }
        if let dividendCagrPct { query["dividend_cagr_pct"] = String(dividendCagrPct) }
        if let historyStartYear { query["history_start_year"] = String(historyStartYear) }
        if let investmentUsd, investmentUsd > 0 {
            query["investment_usd"] = String(investmentUsd)
        }
        if let sharePrice, sharePrice > 0 {
            query["share_price"] = String(sharePrice)
        }
        return try await api.get(
            "/research/dividends",
            query: query,
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchEtfHoldings(
        symbol: String,
        accessToken: String,
        limit: Int = 25,
        api: APIClient = .shared
    ) async throws -> EtfHoldingsContext {
        try await api.get(
            "/research/etf-holdings",
            query: [
                "symbol": symbol.uppercased(),
                "limit": String(limit),
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchFundamentals(
        symbol: String,
        accessToken: String,
        includeAiOverview: Bool = false,
        includeStreetAnalysis: Bool = false,
        api: APIClient = .shared
    ) async throws -> FundamentalsBlock {
        try await api.get(
            "/research/fundamentals",
            query: [
                "symbol": symbol.uppercased(),
                "include_ai_overview": includeAiOverview ? "true" : "false",
                "include_street_analysis": includeStreetAnalysis ? "true" : "false",
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchCompanyNews(
        symbol: String,
        accessToken: String,
        refresh: Bool = false,
        api: APIClient = .shared
    ) async throws -> StockNewsView {
        try await api.get(
            "/get-company-news",
            query: [
                "symbol": symbol.uppercased(),
                "refresh": refresh ? "true" : "false",
            ],
            accessToken: accessToken
        )
    }

    static func analyzeCompanyNews(
        symbol: String,
        accessToken: String,
        refresh: Bool = false,
        api: APIClient = .shared
    ) async throws -> StockNewsView {
        try await api.postNoBody(
            "/analyze-company-news",
            query: [
                "symbol": symbol.uppercased(),
                "refresh": refresh ? "true" : "false",
            ],
            accessToken: accessToken
        )
    }

    static func fetchBusinessDetails(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> BusinessBlock {
        try await api.get(
            "/research/business",
            query: ["symbol": symbol.uppercased()],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchTradeDecision(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> TradeDecision {
        try await api.get(
            "/research/trade-decision",
            query: ["symbol": symbol.uppercased()],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchPositionGuidance(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> SymbolPositionGuidance {
        try await api.get(
            "/research/position-guidance",
            query: ["symbol": symbol.uppercased()],
            accessToken: accessToken,
            keyDecoding: .snakeCase
        )
    }

    static func fetchPortfolioExitAttention(
        accessToken: String,
        limit: Int = 10,
        api: APIClient = .shared
    ) async throws -> PortfolioExitAttentionResponse {
        try await api.get(
            "/portfolio/exit-attention",
            query: ["limit": String(limit)],
            accessToken: accessToken,
            keyDecoding: .snakeCase
        )
    }

    static func fetchSymbolIntelligence(
        symbol: String,
        accessToken: String,
        includeOptions: Bool = true,
        api: APIClient = .shared
    ) async throws -> SymbolIntelligenceDetail {
        try await api.get(
            "/research/intelligence",
            query: [
                "symbol": symbol.uppercased(),
                "include_options": includeOptions ? "true" : "false",
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchWheelBacktest(
        query: WheelBacktestQuery,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> WheelBacktestResult {
        try await api.get(
            "/strategy/wheel-backtest",
            query: query.queryItems,
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }
}
