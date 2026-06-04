import Foundation

enum MomentumBreakoutAlertService {
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
}
