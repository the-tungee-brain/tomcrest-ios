import Foundation

// MARK: - Shared DTOs

struct HistoricalStatsDto: Decodable, Hashable {
    let totalTrades: Int?
    let winRatePct: Double?
    let profitFactor: Double?
    let averageHoldingDays: Double?
}

struct RiskGateDto: Decodable, Hashable {
    let allowed: Bool?
    let action: String?
    let reasons: [String]?
    let recommendedPositionRiskPct: Double?
    let maxNotionalUsd: Double?
    let alertPriority: String?
    let educationalOnly: Bool?
}

// MARK: - Lifecycle

enum MomentumBreakoutLifecycleStatus: String, Decodable, Hashable {
    case pendingEntry = "PENDING_ENTRY"
    case entryTriggered = "ENTRY_TRIGGERED"
    case open = "OPEN"
    case targetHit = "TARGET_HIT"
    case stopHit = "STOP_HIT"
    case expired = "EXPIRED"
    case cancelled = "CANCELLED"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MomentumBreakoutLifecycleStatus(rawValue: raw) ?? .unknown
    }
}

struct AlertLifecycleEventDto: Decodable, Hashable, Identifiable {
    var id: String { eventId }
    let eventId: String
    let eventType: String
    let fromStatus: String?
    let toStatus: String
    let price: Double?
    let recordedAt: String
    let message: String
}

struct MomentumBreakoutAlertDto: Decodable, Hashable, Identifiable {
    var id: String { alertId ?? "\(symbol)-\(createdAt)" }
    let alertId: String?
    let symbol: String
    let setupName: String
    let direction: String?
    let status: String
    let createdAt: String
    let signalDate: String
    let entryPrice: Double
    let stopPrice: Double
    let targetPrice: Double
    let riskReward: Double?
    let entryIsStop: Bool?
    let expiresAt: String?
    let triggeredAt: String?
    let exitAt: String?
    let exitPrice: Double?
    let outcomeReturnPct: Double?
    let riskGateAction: String?
    let riskGateReasons: [String]?
    let priority: String?
    let historicalWinRate: Double?
    let historicalProfitFactor: Double?
    let historicalTotalTrades: Int?
    let nextActionMessage: String?
    let lifecycleEvents: [AlertLifecycleEventDto]?

    var lifecycleStatus: MomentumBreakoutLifecycleStatus {
        MomentumBreakoutLifecycleStatus(rawValue: status) ?? .unknown
    }

    var riskGate: RiskGateDto {
        RiskGateDto(
            allowed: nil,
            action: riskGateAction,
            reasons: riskGateReasons ?? [],
            recommendedPositionRiskPct: nil,
            maxNotionalUsd: nil,
            alertPriority: priority,
            educationalOnly: true
        )
    }

    var historicalStats: HistoricalStatsDto {
        HistoricalStatsDto(
            totalTrades: historicalTotalTrades,
            winRatePct: historicalWinRate.map { $0 <= 1 ? $0 * 100 : $0 },
            profitFactor: historicalProfitFactor,
            averageHoldingDays: nil
        )
    }
}

struct MomentumBreakoutAlertListResponse: Decodable {
    let disclaimer: String
    let alerts: [MomentumBreakoutAlertDto]
}

struct MomentumBreakoutAlertRefreshResponse: Decodable {
    let disclaimer: String
    let processed: Int
    let updated: Int
    let skippedMarketHours: Bool
    let warnings: [String]
    let changes: [MomentumBreakoutAlertStatusChangeDto]?
    let alerts: [MomentumBreakoutAlertDto]
}

struct MomentumBreakoutAlertStatusChangeDto: Decodable, Hashable {
    let alertId: String
    let symbol: String
    let priorStatus: String
    let newStatus: String
}

// MARK: - Notifications

enum MomentumBreakoutNotificationSeverity: String, Decodable, Hashable {
    case info
    case watch
    case warning
    case critical
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MomentumBreakoutNotificationSeverity(rawValue: raw) ?? .unknown
    }
}

struct MomentumBreakoutNotificationDto: Decodable, Hashable, Identifiable {
    var id: String { notificationId }
    let notificationId: String
    let eventType: String
    let title: String
    let body: String
    let severity: String
    let nextActionMessage: String?
    let symbol: String
    let alertId: String?
    let read: Bool
    let createdAt: String
    let alert: MomentumBreakoutAlertDto

    var notificationSeverity: MomentumBreakoutNotificationSeverity {
        MomentumBreakoutNotificationSeverity(rawValue: severity) ?? .unknown
    }
}

struct MomentumBreakoutNotificationListResponse: Decodable {
    let disclaimer: String
    let notifications: [MomentumBreakoutNotificationDto]
}

struct MarkMomentumBreakoutNotificationReadResponse: Decodable {
    let disclaimer: String
    let notification: MomentumBreakoutNotificationDto
}

// MARK: - Live paper-trading performance (not historical backtest)

struct PaperTradePerformanceMetaDto: Decodable, Hashable {
    let label: String
    let disclaimer: String
    let source: String
}

struct PaperTradeSummaryDto: Decodable, Hashable {
    let totalAlerts: Int
    let triggeredAlerts: Int
    let expiredAlerts: Int
    let winRate: Double?
    let averageWin: Double?
    let averageLoss: Double?
    let expectancy: Double?
    let profitFactor: Double?
    let averageHoldingDays: Double?
    let maxDrawdown: Double?
    let currentOpenTrades: Int
}

struct PaperTradeRecordDto: Decodable, Hashable, Identifiable {
    var id: String { alertId }
    let alertId: String
    let symbol: String
    let setupName: String
    let signalDate: String
    let entryTriggeredAt: String?
    let entryPrice: Double
    let stopPrice: Double
    let targetPrice: Double
    let exitAt: String?
    let exitPrice: Double?
    let status: String
    let outcomeReturnPct: Double?
    let holdingDays: Int?
    let riskGateAction: String?
    let marketRegime: String?
    let volumeRatio: Double?
    let rsPercentile: Double?
    let createdAt: String
}

struct PaperTradePerformanceSummaryResponse: Decodable {
    let meta: PaperTradePerformanceMetaDto
    let summary: PaperTradeSummaryDto
    let byRiskGate: [PaperTradeBucketDto]?
}

struct PaperTradeBucketDto: Decodable, Hashable {
    let key: String
    let tradeCount: Int
    let winRate: Double?
    let expectancy: Double?
    let profitFactor: Double?
    let averageReturnPct: Double?
}

struct PaperTradePerformanceTradesResponse: Decodable {
    let meta: PaperTradePerformanceMetaDto
    let trades: [PaperTradeRecordDto]
}

// MARK: - Feature flags

struct MomentumBreakoutFeatureFlagsDto: Decodable, Hashable {
    let alertsEnabled: Bool
    let alertCreationEnabled: Bool
    let alertNotificationsEnabled: Bool
    let paperAnalyticsEnabled: Bool
}

struct MomentumBreakoutFeatureStatusResponse: Decodable {
    let disclaimer: String
    let flags: MomentumBreakoutFeatureFlagsDto
}

// MARK: - Scanner

struct MomentumBreakoutScanCandidateDto: Decodable, Hashable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let entryPrice: Double
    let stopPrice: Double
    let targetPrice: Double
    let riskReward: Double
    let historicalWinRate: Double?
    let historicalProfitFactor: Double?
    let historicalTotalTrades: Int?
    let setupScore: Double
    let stopDistancePct: Double
    let volumeRatio: Double?
    let rsPercentile: Double?
    let marketRegime: String?
    let riskGate: RiskGateDto
}

struct MomentumBreakoutScanResponse: Decodable {
    let scanTime: String
    let totalSymbolsScanned: Int
    let validSetupsFound: Int
    let tradableCandidatesFound: Int
    let blockedCandidatesCount: Int
    let candidatesFound: Int
    let candidates: [MomentumBreakoutScanCandidateDto]
}

// MARK: - Single-stock check & custom plan

enum MomentumBreakoutCheckStatus: String, Decodable, Hashable {
    case tradableBreakout = "TRADABLE_BREAKOUT"
    case rejectedBreakout = "REJECTED_BREAKOUT"
    case noBreakoutSetup = "NO_BREAKOUT_SETUP"
    case dataUnavailable = "DATA_UNAVAILABLE"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MomentumBreakoutCheckStatus(rawValue: raw) ?? .unknown
    }
}

struct MomentumBreakoutCheckResponse: Decodable, Hashable {
    let symbol: String
    let status: MomentumBreakoutCheckStatus
    let verdictTitle: String
    let verdictMessage: String
    let failedSetupRules: [String]
    let rejectionReasons: [String]
    let entryPrice: Double?
    let stopPrice: Double?
    let targetPrice: Double?
    let stopDistancePct: Double?
    let historicalWinRate: Double?
    let historicalProfitFactor: Double?
    let historicalTotalTrades: Int?
    let riskGate: RiskGateDto?
    let canTrackBreakoutPlan: Bool

    var checkStatus: MomentumBreakoutCheckStatus {
        status == .unknown ? .dataUnavailable : status
    }
}

struct MomentumBreakoutTradePlanAlertRequest: Encodable {
    let symbol: String
    let persistAlert: Bool
}

struct MomentumBreakoutTradePlanAlertResponse: Decodable {
    let disclaimer: String
    let planAvailable: Bool
}

struct CustomTradePlanRequest: Encodable {
    let symbol: String
    let direction: String
}

struct CustomTradePlanResponse: Decodable, Hashable {
    let symbol: String
    let setupName: String
    let direction: String
    let entryPrice: Double
    let entryMethod: String
    let currentPrice: Double
    let distanceToEntryPct: Double
    let entryExplanation: String
    let latestBarDate: String
    let planActiveAtCurrentPrice: Bool
    let stopPrice: Double
    let targetPrice: Double
    let riskReward: Double
    let warnings: [String]
    let educationalOnly: Bool
}
