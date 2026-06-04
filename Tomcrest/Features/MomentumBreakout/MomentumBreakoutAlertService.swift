import Foundation

enum MomentumBreakoutAlertService {
    static func fetchScan(
        accessToken: String,
        tradableOnly: Bool = false,
        limit: Int = 50,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutScanResponse {
        try await api.get(
            "/strategy/momentum-breakout/scan",
            query: [
                "tradableOnly": tradableOnly ? "true" : "false",
                "limit": String(limit),
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase,
            sessionKind: .longRunning
        )
    }

    static func fetchTopCandidates(
        accessToken: String,
        tradableOnly: Bool = false,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutScanResponse {
        try await api.get(
            "/strategy/momentum-breakout/top-candidates",
            query: ["tradableOnly": tradableOnly ? "true" : "false"],
            accessToken: accessToken,
            keyDecoding: .camelCase,
            sessionKind: .longRunning
        )
    }

    static func fetchActiveAlerts(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutAlertListResponse {
        try await api.get(
            "/strategy/momentum-breakout/alerts/active",
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchAlertHistory(
        accessToken: String,
        limit: Int = 100,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutAlertListResponse {
        try await api.get(
            "/strategy/momentum-breakout/alerts/history",
            query: ["limit": String(limit)],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func cancelAlert(
        accessToken: String,
        alertId: String,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutAlertDto {
        try await api.postNoBody(
            "/strategy/momentum-breakout/alerts/\(alertId)/cancel",
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func refreshAlerts(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutAlertRefreshResponse {
        try await api.postNoBody(
            "/strategy/momentum-breakout/alerts/refresh",
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchNotifications(
        accessToken: String,
        unreadOnly: Bool = false,
        limit: Int = 50,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutNotificationListResponse {
        try await api.get(
            "/strategy/momentum-breakout/notifications",
            query: [
                "unreadOnly": unreadOnly ? "true" : "false",
                "limit": String(limit),
            ],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func markNotificationRead(
        accessToken: String,
        notificationId: String,
        api: APIClient = .shared
    ) async throws -> MarkMomentumBreakoutNotificationReadResponse {
        try await api.postNoBody(
            "/strategy/momentum-breakout/notifications/\(notificationId)/read",
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchPaperPerformanceSummary(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> PaperTradePerformanceSummaryResponse {
        try await api.get(
            "/strategy/momentum-breakout/performance/summary",
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchPaperPerformanceTrades(
        accessToken: String,
        limit: Int = 12,
        api: APIClient = .shared
    ) async throws -> PaperTradePerformanceTradesResponse {
        try await api.get(
            "/strategy/momentum-breakout/performance/trades",
            query: ["limit": String(limit)],
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchFeatureStatus(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutFeatureStatusResponse {
        try await api.get(
            "/strategy/momentum-breakout/feature-status",
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func fetchCheck(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutCheckResponse {
        let encoded = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return try await api.get(
            "/strategy/momentum-breakout/check/\(encoded)",
            accessToken: accessToken,
            keyDecoding: .camelCase,
            sessionKind: .longRunning
        )
    }

    static func postTradePlanAlert(
        symbol: String,
        accessToken: String,
        persistAlert: Bool = true,
        api: APIClient = .shared
    ) async throws -> MomentumBreakoutTradePlanAlertResponse {
        let body = MomentumBreakoutTradePlanAlertRequest(
            symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            persistAlert: persistAlert
        )
        return try await api.post(
            "/strategy/momentum-breakout/trade-plan-alert",
            body: body,
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }

    static func postCustomTradePlan(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> CustomTradePlanResponse {
        let body = CustomTradePlanRequest(
            symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            direction: "LONG"
        )
        return try await api.post(
            "/strategy/custom-trade-plan",
            body: body,
            accessToken: accessToken,
            keyDecoding: .camelCase
        )
    }
}
