import Foundation

#if DEBUG
enum MomentumBreakoutAlertMocks {
    static let disclaimer =
        "Educational alert tracking only. Not investment advice. No orders are placed."

    static var pending: MomentumBreakoutAlertDto {
        alert(
            status: "PENDING_ENTRY",
            riskGateAction: "ALLOW",
            reasons: [educationalReason]
        )
    }

    static var open: MomentumBreakoutAlertDto {
        alert(
            status: "OPEN",
            triggeredAt: "2024-06-02T14:00:00Z",
            riskGateAction: "ALLOW",
            reasons: [educationalReason]
        )
    }

    static var targetHit: MomentumBreakoutAlertDto {
        alert(
            status: "TARGET_HIT",
            triggeredAt: "2024-06-02T14:00:00Z",
            exitAt: "2024-06-03T14:00:00Z",
            exitPrice: 110,
            outcomeReturnPct: 0.1,
            riskGateAction: "ALLOW",
            reasons: []
        )
    }

    static var stopHit: MomentumBreakoutAlertDto {
        alert(
            status: "STOP_HIT",
            triggeredAt: "2024-06-02T14:00:00Z",
            exitAt: "2024-06-03T10:00:00Z",
            exitPrice: 94,
            outcomeReturnPct: -0.06,
            riskGateAction: "ALLOW",
            reasons: []
        )
    }

    static var blockedRiskGate: MomentumBreakoutAlertDto {
        alert(
            status: "CANCELLED",
            riskGateAction: "BLOCK",
            reasons: [
                "Max open positions reached (5/5 active momentum_breakout trades).",
                educationalReason,
            ]
        )
    }

    static var warningRiskGate: MomentumBreakoutAlertDto {
        alert(
            status: "PENDING_ENTRY",
            riskGateAction: "WARN",
            reasons: [
                "Elevated mega-cap correlation exposure.",
                educationalReason,
            ]
        )
    }

    private static let educationalReason =
        "Educational trade plan alert only — not investment advice. No orders are placed."

    private static func alert(
        status: String,
        triggeredAt: String? = nil,
        exitAt: String? = nil,
        exitPrice: Double? = nil,
        outcomeReturnPct: Double? = nil,
        riskGateAction: String,
        reasons: [String]
    ) -> MomentumBreakoutAlertDto {
        MomentumBreakoutAlertDto(
            alertId: "preview-alert-id",
            symbol: "NVDA",
            setupName: "momentum_breakout",
            direction: "LONG",
            status: status,
            createdAt: "2024-06-01T15:00:00Z",
            signalDate: "2024-06-01",
            entryPrice: 100,
            stopPrice: 95,
            targetPrice: 110,
            riskReward: 2,
            entryIsStop: true,
            expiresAt: "2024-06-02T23:59:59Z",
            triggeredAt: triggeredAt,
            exitAt: exitAt,
            exitPrice: exitPrice,
            outcomeReturnPct: outcomeReturnPct,
            riskGateAction: riskGateAction,
            riskGateReasons: reasons,
            priority: "HIGH",
            historicalWinRate: 0.42,
            historicalProfitFactor: 1.35,
            historicalTotalTrades: 136,
            nextActionMessage: "Track price versus stop and target; monitoring only.",
            lifecycleEvents: []
        )
    }

    static func notification(
        eventType: String,
        severity: String,
        title: String,
        body: String,
        alert: MomentumBreakoutAlertDto,
        read: Bool = false
    ) -> MomentumBreakoutNotificationDto {
        MomentumBreakoutNotificationDto(
            notificationId: UUID().uuidString,
            eventType: eventType,
            title: title,
            body: body,
            severity: severity,
            nextActionMessage: alert.nextActionMessage,
            symbol: alert.symbol,
            alertId: alert.alertId,
            read: read,
            createdAt: "2024-06-02T14:00:05Z",
            alert: alert
        )
    }
}
#endif
