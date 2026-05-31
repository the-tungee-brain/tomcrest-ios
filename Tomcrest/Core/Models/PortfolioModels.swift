import Foundation

struct Instrument: Codable {
    let assetType: String
    let symbol: String
    let description: String?
    let underlyingSymbol: String?

    enum CodingKeys: String, CodingKey {
        case assetType
        case symbol
        case description
        case underlyingSymbol
    }
}

struct Position: Codable, Identifiable {
    var id: String { "\(instrument.symbol)-\(marketValue)-\(longQuantity)" }

    let longQuantity: Double
    let marketValue: Double
    let currentDayProfitLoss: Double
    let currentDayProfitLossPercentage: Double
    let instrument: Instrument
    let openProfitLoss: Double?
    let openProfitLossPct: Double?
    let portfolioWeightPct: Double?

    var displaySymbol: String {
        if instrument.assetType == "OPTION", let underlying = instrument.underlyingSymbol {
            return underlying
        }
        return instrument.symbol
    }
}

struct PortfolioMetrics: Codable {
    let totalOpenProfitLoss: Double?
    let totalCostBasis: Double?
    let openProfitLossPct: Double?
}

struct CurrentBalances: Codable {
    let liquidationValue: Double
    let buyingPower: Double
    let equity: Double
    let cashBalance: Double
}

struct SecuritiesAccount: Codable {
    let accountNumber: String
    let positions: [Position]
    let currentBalances: CurrentBalances
}

struct AggregatedBalance: Codable {
    let currentLiquidationValue: Double
}

struct SchwabAccounts: Codable {
    let securitiesAccount: SecuritiesAccount
    let aggregatedBalance: AggregatedBalance
}

struct PositionsDataFreshness: Codable {
    let positionsSyncedAt: String?
    let briefStatus: String?
}

struct AccountPositionsResponse: Decodable {
    let schwabPositions: [String: [Position]]
    let account: SchwabAccounts
    let proactiveAlerts: [ProactiveAlert]?
    let portfolioBrief: PortfolioIntelligence?
    let portfolioMetrics: PortfolioMetrics?
    let dataFreshness: PositionsDataFreshness?
    let recentActivity: RecentActivitySummary?
    let cashSecuredPutSummary: CashSecuredPutSummary?
    let assignmentRiskSummary: AssignmentRiskSummary?

    enum CodingKeys: String, CodingKey {
        case schwabPositions = "schwab_positions"
        case account
        case proactiveAlerts
        case portfolioBrief
        case portfolioMetrics
        case dataFreshness
        case recentActivity
        case cashSecuredPutSummary
        case assignmentRiskSummary
    }

    var flattenedPositions: [Position] {
        schwabPositions.values.flatMap { $0 }
    }
}

struct PortfolioDigest: Codable {
    let sectorWeights: [SectorWeight]?
    let macroRegime: String?
    let topNews: [PortfolioDigestNewsItem]?
    let earningsThisWeek: [String]?
}

struct SectorWeight: Codable, Identifiable {
    var id: String { sector }
    let sector: String
    let weightPct: Double
    let symbols: [String]
}

struct PortfolioDigestNewsItem: Codable, Identifiable {
    var id: String { "\(symbol)-\(headline)" }
    let symbol: String
    let headline: String
    let sentiment: String?
    let weightPct: Double?
    let url: String?
}

struct PortfolioChanges: Codable {
    let summary: String?
    let liquidationValueChangePct: Double?
}

struct AttentionItem: Codable, Identifiable {
    var id: String { alertId ?? "\(action)-\(label)-\(priority)" }

    let action: String
    let label: String
    let reason: String
    let priority: Int
    let symbol: String?
    let alertId: String?
}

struct MorningBrief: Codable {
    let generatedAt: String
    let macroRegime: String?
    let digest: PortfolioDigest?
    let changes: PortfolioChanges?
    let signals: [IntelligenceSignal]
    let topAlerts: [ProactiveAlert]
    let attentionQueue: [AttentionItem]
    let deliveryReady: Bool

    var portfolioIntelligence: PortfolioIntelligence {
        PortfolioIntelligence(
            signals: signals,
            digest: digest,
            alerts: topAlerts
        )
    }
}

struct DismissAlertResponse: Decodable {
    let dismissed: Bool
}

struct AccountSnapshot {
    let liquidationValue: Double
    let buyingPower: Double
    let equity: Double
    let cashBalance: Double
    let positionCount: Int
    let symbolCount: Int
    let totalOpenProfitLoss: Double?
    let openProfitLossPct: Double?

    init(account: SchwabAccounts, metrics: PortfolioMetrics?, positions: [Position]) {
        let balances = account.securitiesAccount.currentBalances
        liquidationValue = balances.liquidationValue
        buyingPower = balances.buyingPower
        equity = balances.equity
        cashBalance = balances.cashBalance
        positionCount = positions.count
        symbolCount = Set(positions.map(\.displaySymbol)).count
        totalOpenProfitLoss = metrics?.totalOpenProfitLoss
        openProfitLossPct = metrics?.openProfitLossPct
    }
}

// MARK: - Portfolio news (GET /portfolio/news)

struct PortfolioHoldingsNewsItem: Decodable, Identifiable {
    var id: String { "\(symbol)-\(headline)-\(publishedAt ?? "")" }
    let symbol: String
    let headline: String
    let source: String?
    let summary: String?
    let url: String?
    let weightPct: Double?
    let publishedAt: String?
}

struct PortfolioNewsResponse: Decodable {
    let items: [PortfolioHoldingsNewsItem]
}

// MARK: - Recent orders (GET /recent-orders)

struct SuggestedAnalysisAction: Codable, Identifiable {
    var id: String { "\(action)-\(priority)-\(label)" }

    let action: String
    let label: String
    let reason: String
    let priority: Int
}

struct RecentOrderLegEntry: Decodable, Identifiable {
    var id: String { "\(legId ?? 0)-\(instruction)-\(quantity ?? 0)" }

    let legId: Int?
    let instruction: String
    let quantity: Double?
    let assetType: String?
    let contractLabel: String?
    let averageFillPrice: Double?
    let premiumPerContract: Double?
    let totalCash: Double?
}

struct RecentOrderEntry: Decodable, Identifiable {
    var id: String { "\(orderId ?? 0)-\(fillTime ?? "")-\(symbol)-\(side)" }

    let orderId: Int?
    let symbol: String
    let fillTime: String?
    let side: String
    let quantity: Double?
    let averageFillPrice: Double?
    let premiumPerContract: Double?
    let totalCash: Double?
    let orderType: String?
    let assetType: String?
    let legCount: Int?
    let strategyLabel: String?
    let contractLabel: String?
    let legs: [RecentOrderLegEntry]?
    let activityGroupId: String?
    let activityGroupKind: String?
    let activityGroupLabel: String?
}

struct RecentOrdersResponse: Decodable {
    let daysBack: Int
    let symbol: String?
    let orders: [RecentOrderEntry]
    let totalOrders: Int
    let recentOrderCount: Int
    let limit: Int
    let offset: Int
    let suggestedActions: [SuggestedAnalysisAction]?
    let activityBySymbol: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case daysBack
        case symbol
        case orders
        case totalOrders
        case recentOrderCount
        case limit
        case offset
        case suggestedActions
        case activityBySymbol
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        daysBack = try container.decode(Int.self, forKey: .daysBack)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        orders = try container.decode([RecentOrderEntry].self, forKey: .orders)
        totalOrders = try container.decode(Int.self, forKey: .totalOrders)
        recentOrderCount = try container.decode(Int.self, forKey: .recentOrderCount)
        limit = try container.decode(Int.self, forKey: .limit)
        offset = try container.decode(Int.self, forKey: .offset)
        suggestedActions = try container.decodeIfPresent([SuggestedAnalysisAction].self, forKey: .suggestedActions)
        activityBySymbol = try container.decodeIfPresent([String: Int].self, forKey: .activityBySymbol)
    }
}

struct RecentActivitySummary: Decodable {
    let daysBack: Int
    let totalOrders: Int
    let recentOrderCount: Int
    let suggestedActions: [SuggestedAnalysisAction]?

    enum CodingKeys: String, CodingKey {
        case daysBack
        case totalOrders
        case recentOrderCount
        case suggestedActions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        daysBack = try container.decode(Int.self, forKey: .daysBack)
        totalOrders = try container.decode(Int.self, forKey: .totalOrders)
        recentOrderCount = try container.decode(Int.self, forKey: .recentOrderCount)
        suggestedActions = try container.decodeIfPresent([SuggestedAnalysisAction].self, forKey: .suggestedActions)
    }
}
