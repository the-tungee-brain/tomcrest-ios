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

    enum CodingKeys: String, CodingKey {
        case schwabPositions = "schwab_positions"
        case account
        case proactiveAlerts
        case portfolioBrief
        case portfolioMetrics
        case dataFreshness
    }

    var flattenedPositions: [Position] {
        schwabPositions.values.flatMap { $0 }
    }
}

struct PortfolioDigest: Codable {
    let macroRegime: String?
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
