import Foundation

struct NewsHeadline: Decodable, Identifiable {
    var id: String { "\(headline)-\(datetime)" }
    let headline: String
    let summary: String?
    let source: String
    let datetime: String
    let url: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        headline = try container.decode(String.self, forKey: .headline)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        datetime = try container.decodeIfPresent(String.self, forKey: .datetime) ?? ""
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }

    private enum CodingKeys: String, CodingKey {
        case headline, summary, source, datetime, url
    }
}

struct PressReleasesResponse: Decodable {
    let symbol: String
    let items: [NewsHeadline]
}

struct EarningsEvent: Decodable, Identifiable {
    var id: String { "\(reportDate)-\(fiscalPeriod)" }
    let symbol: String
    let reportDate: String
    let fiscalPeriod: String
    let timing: String?
    let epsActual: Double?
    let epsEstimate: Double?
    let epsSurprisePct: Double?
    let revenueActual: Double?
    let revenueEstimate: Double?
    let revenueSurprisePct: Double?
    let beatLabel: String?
    let isUpcoming: Bool
}

struct EarningsListResponse: Decodable {
    let symbol: String
    let upcoming: EarningsEvent?
    let history: [EarningsEvent]
}

struct TranscriptSegment: Decodable, Identifiable {
    var id: String { "\(speaker)-\(text.prefix(24))" }
    let speaker: String
    let role: String?
    let text: String
}

struct EarningsAnalysis: Decodable {
    let headline: String
    let summary: String
    let context: String
    let keyHighlights: [String]
    let guidanceAndOutlook: String
    let whatSurprised: String
    let investorTakeaway: String
}

struct EarningsDetailResponse: Decodable {
    let symbol: String
    let event: EarningsEvent
    let relatedNews: [NewsHeadline]
    let officialReleases: [NewsHeadline]
    let transcriptAvailable: Bool
    let transcript: [TranscriptSegment]
    let analysis: EarningsAnalysis?
}

struct DividendPaymentItem: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let amountPerShare: Double
}

struct AnnualDividendIncome: Decodable, Identifiable {
    var id: Int { year }
    let year: Int
    let totalPerShare: Double
    let incomeOnShares: Double
}

struct DividendHistoryContext: Decodable {
    let ticker: String
    let totalDividends: Int
    let consecutiveAnnualIncreases: Int
    let dividendYieldPct: Double?
    let cagr5yPct: Double?
    let annualIncome: [AnnualDividendIncome]
    let recentPayments: [DividendPaymentItem]
    let dataAsOf: String?
    let scenario: DividendSnowballScenario?
    let historicalBacktest: DividendHistoricalBacktest?
}

struct DividendSnowballScenario: Decodable {
    let shares: Double
    let startYear: Int
    let totalCollected: Double
    let annualIncomeLatest: Double
    let annualIncomeStart: Double
    let latestYear: Int
    let projectYears: Int
    let dividendCagrPct: Double
    let advanced: DividendAdvancedSnowballScenario?
}

struct DividendAdvancedSnowballScenario: Decodable {
    let initialShares: Double
    let finalShares: Double
    let sharePriceAtStart: Double
    let sharePriceLatest: Double
    let priceCagrPct: Double
    let annualIncomeLatestDrip: Double
    let portfolioValueLatest: Double
    let totalDividendsReinvested: Double
    let totalAnnualContributionsUsd: Double
    let usesHistoricalSharePrices: Bool?
}

struct DividendBacktestYearRow: Decodable, Identifiable {
    var id: Int { year }
    let year: Int
    let dps: Double
    let shares: Double
    let dividendIncome: Double
    let sharePrice: Double
    let dividendYieldPct: Double
}

struct DividendHistoricalBacktest: Decodable {
    let startYear: Int
    let endYear: Int
    let initialShares: Double?
    let cashCollected: Double
    let cashCollectedAnnual: Double
    let yearlyBreakdown: [DividendBacktestYearRow]
    let drip: DividendAdvancedSnowballScenario?
}

struct DividendBacktestQuery: Equatable {
    var shares: Double = 0
    var investmentUsd: Double = 0
    var reinvestDividends: Bool = true
    var annualContributionUsd: Double = 0
    var lookbackYears: Int = 10
}

enum DividendBacktestSupport {
    static let lookbackPresets = [5, 10, 15]

    static func roundScenarioValue(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    static func deriveSharePriceAtStart(
        currentSharePrice: Double,
        priceCagrPct: Double,
        yearsElapsed: Int
    ) -> Double {
        guard yearsElapsed > 0, currentSharePrice > 0 else {
            return roundScenarioValue(currentSharePrice)
        }
        let rate = priceCagrPct / 100
        let denominator = pow(1 + rate, Double(yearsElapsed))
        guard denominator > 0 else {
            return roundScenarioValue(currentSharePrice)
        }
        return roundScenarioValue(currentSharePrice / denominator)
    }

    static func resolveStartSharePrice(
        context: DividendHistoryContext,
        marketSharePrice: Double?,
        startYear: Int,
        endYear: Int
    ) -> Double? {
        if let backtest = context.historicalBacktest,
           backtest.startYear == startYear,
           let drip = backtest.drip,
           drip.sharePriceAtStart > 0 {
            return drip.sharePriceAtStart
        }

        if let row = context.historicalBacktest?.yearlyBreakdown.first(where: { $0.year == startYear }),
           row.sharePrice > 0 {
            return row.sharePrice
        }

        let latestPrice = marketSharePrice
            ?? context.scenario?.advanced?.sharePriceLatest
            ?? context.historicalBacktest?.yearlyBreakdown.last?.sharePrice

        guard let latestPrice, latestPrice > 0 else { return nil }

        let priceCagrPct = context.scenario?.advanced?.priceCagrPct
            ?? context.historicalBacktest?.drip?.priceCagrPct
            ?? 0
        let yearsElapsed = max(0, endYear - startYear)
        return deriveSharePriceAtStart(
            currentSharePrice: latestPrice,
            priceCagrPct: priceCagrPct,
            yearsElapsed: yearsElapsed
        )
    }

    static func resolveMarketSharePrice(
        context: DividendHistoryContext,
        marketSharePrice: Double?
    ) -> Double? {
        if let marketSharePrice, marketSharePrice > 0 { return marketSharePrice }
        if let latest = context.scenario?.advanced?.sharePriceLatest, latest > 0 { return latest }
        if let latest = context.historicalBacktest?.yearlyBreakdown.last?.sharePrice, latest > 0 {
            return latest
        }
        return nil
    }

    static func syncFromInvestment(_ investmentUsd: Double, startSharePrice: Double?) -> (investmentUsd: Double, shares: Double) {
        guard investmentUsd > 0, let startSharePrice, startSharePrice > 0 else {
            return (0, 0)
        }
        let investment = roundScenarioValue(investmentUsd)
        return (investment, roundScenarioValue(investment / startSharePrice))
    }

    static func syncFromShares(_ shares: Double, startSharePrice: Double?) -> (investmentUsd: Double, shares: Double) {
        guard shares > 0, let startSharePrice, startSharePrice > 0 else {
            return (0, 0)
        }
        let resolvedShares = roundScenarioValue(shares)
        return (roundScenarioValue(resolvedShares * startSharePrice), resolvedShares)
    }

    static func canRunBacktest(query: DividendBacktestQuery, startSharePrice: Double?) -> Bool {
        guard let startSharePrice, startSharePrice > 0 else { return false }
        return query.investmentUsd > 0 || query.shares > 0
    }

    static func resolveQueryForRun(
        _ query: DividendBacktestQuery,
        context: DividendHistoryContext,
        marketSharePrice: Double?,
        startYear: Int,
        endYear: Int
    ) -> (query: DividendBacktestQuery, sharePrice: Double?) {
        var resolved = query
        let startPrice = resolveStartSharePrice(
            context: context,
            marketSharePrice: marketSharePrice,
            startYear: startYear,
            endYear: endYear
        )

        if resolved.investmentUsd > 0, let startPrice, startPrice > 0 {
            let synced = syncFromInvestment(resolved.investmentUsd, startSharePrice: startPrice)
            resolved.investmentUsd = synced.investmentUsd
            resolved.shares = synced.shares
        } else if resolved.shares > 0, let startPrice, startPrice > 0 {
            let synced = syncFromShares(resolved.shares, startSharePrice: startPrice)
            resolved.investmentUsd = synced.investmentUsd
            resolved.shares = synced.shares
        }

        return (resolved, resolveMarketSharePrice(context: context, marketSharePrice: marketSharePrice))
    }

    static func completedYears(from context: DividendHistoryContext) -> [Int] {
        context.annualIncome.map(\.year).sorted()
    }

    static func historyStartYear(completedYears: [Int], lookbackYears: Int) -> Int? {
        guard let endYear = completedYears.last, let firstYear = completedYears.first else { return nil }
        let span = max(1, lookbackYears)
        return max(firstYear, endYear - (span - 1))
    }

    static func maxLookbackYears(completedYears: [Int]) -> Int {
        min(15, max(completedYears.count, 1))
    }
}

struct FundamentalMetric: Decodable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let note: String?
}

struct FinancialCategoryScore: Decodable {
    let score: Int
    let rankLabel: String
}

struct FinancialScoreBreakdown: Decodable {
    let growth: FinancialCategoryScore
    let profitability: FinancialCategoryScore
    let balanceSheet: FinancialCategoryScore
    let cashFlow: FinancialCategoryScore
}

struct FinancialStrength: Decodable {
    let profile: String
    let score: Int
    let financialVerdict: String
    let scoreExplanation: String
    let businessContext: String
    let scoreBreakdown: FinancialScoreBreakdown
    let rating: String
    let headline: String
    let strengths: [String]
    let risks: [String]
    let highlights: [String]?
    let keyMetrics: [FundamentalMetric]?

    enum CodingKeys: String, CodingKey {
        case profile, score, financialVerdict, scoreExplanation, scoreBreakdown
        case businessContext, rating, headline, strengths, risks, highlights, keyMetrics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(String.self, forKey: .profile)
        score = try container.decode(Int.self, forKey: .score)
        let verdict = try container.decodeIfPresent(String.self, forKey: .financialVerdict)
        let explanation = try container.decodeIfPresent(String.self, forKey: .scoreExplanation) ?? ""
        financialVerdict = verdict ?? explanation
        scoreExplanation = explanation.isEmpty ? financialVerdict : explanation
        businessContext = try container.decodeIfPresent(String.self, forKey: .businessContext) ?? ""
        scoreBreakdown = try container.decode(FinancialScoreBreakdown.self, forKey: .scoreBreakdown)
        rating = try container.decode(String.self, forKey: .rating)
        headline = try container.decode(String.self, forKey: .headline)
        strengths = try container.decodeIfPresent([String].self, forKey: .strengths) ?? []
        risks = try container.decodeIfPresent([String].self, forKey: .risks) ?? []
        highlights = try container.decodeIfPresent([String].self, forKey: .highlights)
        keyMetrics = try container.decodeIfPresent([FundamentalMetric].self, forKey: .keyMetrics)
    }
}

struct InvestmentThesis: Decodable {
    let bullCase: [String]
    let bearCase: [String]
}

struct ValuationSignal: Decodable, Identifiable {
    var id: String { "\(label)-\(value)" }
    let label: String
    let value: String
    let note: String?
}

struct FundamentalsOverview: Decodable {
    let valuationConclusion: String
    let valuationSummary: String
    let valuationSignals: [ValuationSignal]
    let investmentThesis: InvestmentThesis
    let streetContext: String?
}

struct FundamentalsBlock: Decodable {
    let overview: FundamentalsOverview?
    let overviewNote: String?
    let metrics: [FundamentalMetric]
    let strength: FinancialStrength?
    let streetAnalysis: StreetAnalysisSnapshot?
    let quarterlyFinancials: FinancialStatementsSnapshot?
    let annualFinancials: FinancialStatementsSnapshot?
    let etfFunds: EtfFundsSnapshot?
}

struct FinancialLineItem: Decodable, Identifiable {
    var id: String { label }
    let label: String
    let values: [String: Double]

    enum CodingKeys: String, CodingKey {
        case label
        case values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        if let raw = try container.decodeIfPresent([String: Double?].self, forKey: .values) {
            values = raw.compactMapValues { $0 }
        } else {
            values = [:]
        }
    }
}

struct FinancialStatementsSnapshot: Decodable {
    let periods: [String]
    let incomeStatement: [FinancialLineItem]
    let balanceSheet: [FinancialLineItem]
    let cashFlow: [FinancialLineItem]

    private enum CodingKeys: String, CodingKey {
        case periods
        case incomeStatement
        case balanceSheet
        case cashFlow
        case incomeStatementSnake = "income_statement"
        case balanceSheetSnake = "balance_sheet"
        case cashFlowSnake = "cash_flow"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        periods = try container.decodeIfPresent([String].self, forKey: .periods) ?? []
        incomeStatement = try container.decodeIfPresent([FinancialLineItem].self, forKey: .incomeStatement)
            ?? container.decodeIfPresent([FinancialLineItem].self, forKey: .incomeStatementSnake) ?? []
        balanceSheet = try container.decodeIfPresent([FinancialLineItem].self, forKey: .balanceSheet)
            ?? container.decodeIfPresent([FinancialLineItem].self, forKey: .balanceSheetSnake) ?? []
        cashFlow = try container.decodeIfPresent([FinancialLineItem].self, forKey: .cashFlow)
            ?? container.decodeIfPresent([FinancialLineItem].self, forKey: .cashFlowSnake) ?? []
    }
}

struct EtfFundsSnapshot: Decodable {
    let category: String?
    let fundFamily: String?
    let totalAssets: String?
    let yield: String?
    let ytdReturn: String?
}

struct EtfHoldingItem: Decodable, Identifiable {
    var id: String { "\(ticker ?? name)-\(weightPct)" }
    let ticker: String?
    let name: String
    let weightPct: Double
    let sector: String?
    let marketCap: String?
    let piotroskiF: Int?
    let altmanZ: Double?

    enum CodingKeys: String, CodingKey {
        case ticker, name, sector
        case weightPct
        case weightPctSnake = "weight_pct"
        case marketCap
        case marketCapSnake = "market_cap"
        case piotroskiF
        case altmanZ
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ticker = try container.decodeIfPresent(String.self, forKey: .ticker)
        name = try container.decode(String.self, forKey: .name)
        weightPct = try container.decodeIfPresent(Double.self, forKey: .weightPct)
            ?? container.decode(Double.self, forKey: .weightPctSnake)
        sector = try container.decodeIfPresent(String.self, forKey: .sector)
        marketCap = try container.decodeIfPresent(String.self, forKey: .marketCap)
            ?? container.decodeIfPresent(String.self, forKey: .marketCapSnake)
        piotroskiF = try container.decodeIfPresent(Int.self, forKey: .piotroskiF)
        altmanZ = try container.decodeIfPresent(Double.self, forKey: .altmanZ)
    }
}

struct EtfHoldingsContext: Decodable {
    let ticker: String
    let totalHoldings: Int
    let aum: String?
    let sectorBreakdown: [String: Double]
    let holdings: [EtfHoldingItem]
    let strongestHoldings: [EtfHoldingItem]
    let weakestHoldings: [EtfHoldingItem]
    let dividendYield: String?
    let expenseRatio: String?
    let dataAsOf: String?

    enum CodingKeys: String, CodingKey {
        case ticker, aum, holdings
        case totalHoldings
        case totalHoldingsSnake = "total_holdings"
        case sectorBreakdown
        case sectorBreakdownSnake = "sector_breakdown"
        case strongestHoldings
        case weakestHoldings
        case dividendYield
        case dividendYieldSnake = "dividend_yield"
        case expenseRatio
        case expenseRatioSnake = "expense_ratio"
        case dataAsOf
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ticker = try container.decode(String.self, forKey: .ticker)
        totalHoldings = try container.decodeIfPresent(Int.self, forKey: .totalHoldings)
            ?? container.decode(Int.self, forKey: .totalHoldingsSnake)
        aum = try container.decodeIfPresent(String.self, forKey: .aum)
        sectorBreakdown = try container.decodeIfPresent(
            [String: Double].self,
            forKey: .sectorBreakdown
        ) ?? container.decodeIfPresent(
            [String: Double].self,
            forKey: .sectorBreakdownSnake
        ) ?? [:]
        holdings = try container.decodeIfPresent([EtfHoldingItem].self, forKey: .holdings) ?? []
        strongestHoldings = try container.decodeIfPresent(
            [EtfHoldingItem].self,
            forKey: .strongestHoldings
        ) ?? []
        weakestHoldings = try container.decodeIfPresent(
            [EtfHoldingItem].self,
            forKey: .weakestHoldings
        ) ?? []
        dividendYield = try container.decodeIfPresent(String.self, forKey: .dividendYield)
            ?? container.decodeIfPresent(String.self, forKey: .dividendYieldSnake)
        expenseRatio = try container.decodeIfPresent(String.self, forKey: .expenseRatio)
            ?? container.decodeIfPresent(String.self, forKey: .expenseRatioSnake)
        dataAsOf = try container.decodeIfPresent(String.self, forKey: .dataAsOf)
    }
}

struct AnalystPriceTargets: Decodable {
    let current: Double?
    let low: Double?
    let high: Double?
    let mean: Double?
    let median: Double?
    let upsideToMeanPct: Double?
}

struct RecommendationBreakdown: Decodable {
    let strongBuy: Int
    let buy: Int
    let hold: Int
    let sell: Int
    let strongSell: Int

    var total: Int {
        strongBuy + buy + hold + sell + strongSell
    }

    private enum CodingKeys: String, CodingKey {
        case strongBuy, buy, hold, sell, strongSell
        case strongBuySnake = "strong_buy"
        case strongSellSnake = "strong_sell"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strongBuy = try container.decodeIfPresent(Int.self, forKey: .strongBuy)
            ?? container.decodeIfPresent(Int.self, forKey: .strongBuySnake) ?? 0
        buy = try container.decodeIfPresent(Int.self, forKey: .buy) ?? 0
        hold = try container.decodeIfPresent(Int.self, forKey: .hold) ?? 0
        sell = try container.decodeIfPresent(Int.self, forKey: .sell) ?? 0
        strongSell = try container.decodeIfPresent(Int.self, forKey: .strongSell)
            ?? container.decodeIfPresent(Int.self, forKey: .strongSellSnake) ?? 0
    }
}

struct InstitutionalHolder: Decodable, Identifiable {
    var id: String { holder }
    let holder: String
    let pctHeld: Double?
    let shares: Double?
    let value: Double?
}

struct InsiderTransactionRow: Decodable, Identifiable {
    var id: String { "\(date)-\(insider)-\(transaction ?? "")" }
    let date: String
    let insider: String
    let transaction: String?
    let shares: Double?
    let value: Double?
}

struct OwnershipSnapshot: Decodable {
    let insidersPctHeld: Double?
    let institutionsPctHeld: Double?
    let topInstitutional: [InstitutionalHolder]?
    let recentInsiderTransactions: [InsiderTransactionRow]?
}

struct AnalystRatingAction: Decodable, Identifiable {
    var id: String { "\(date)-\(firm)-\(toGrade)" }
    let date: String
    let firm: String
    let toGrade: String
    let fromGrade: String?
    let action: String?
}

struct StreetAnalysisSnapshot: Decodable {
    let priceTargets: AnalystPriceTargets?
    let recommendation: RecommendationBreakdown?
    let consensusLabel: String?
    let growthContextHeadline: String?
    let ratingTrendHeadline: String?
    let estimateRevisionHeadline: String?
    let estimateDriftHeadline: String?
    let recentRatingActions: [AnalystRatingAction]?
    let ownership: OwnershipSnapshot?
    let dataAsOf: String?
}

enum StreetAnalysisFormatters {
    static func hasStreetAnalysis(_ street: StreetAnalysisSnapshot?) -> Bool {
        guard let street else { return false }
        if street.consensusLabel != nil { return true }
        if street.recommendation?.total ?? 0 > 0 { return true }
        if street.priceTargets?.mean != nil { return true }
        if !(street.recentRatingActions ?? []).isEmpty { return true }
        return false
    }

    static func hasOwnership(_ ownership: OwnershipSnapshot?) -> Bool {
        guard let ownership else { return false }
        if ownership.insidersPctHeld != nil || ownership.institutionsPctHeld != nil { return true }
        if !(ownership.topInstitutional ?? []).isEmpty { return true }
        if !(ownership.recentInsiderTransactions ?? []).isEmpty { return true }
        return false
    }

    static func formatPctHeld(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }

    static func formatPrice(_ value: Double?) -> String {
        guard let value else { return "—" }
        return CurrencyFormatter.usd(value)
    }

    static func formatUpside(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%+.1f%%", value)
    }

    static func formatPremiumDiscountToTarget(
        current: Double?,
        mean: Double?,
        upsideToMeanPct: Double?
    ) -> String {
        if let upside = upsideToMeanPct {
            if upside >= 0.5 {
                return String(format: "%.1f%% below mean target", upside)
            }
            if upside <= -0.5 {
                return String(format: "%.1f%% above mean target", abs(upside))
            }
            return "At mean target"
        }
        guard let current, let mean, mean != 0 else { return "—" }
        let pct = ((current - mean) / mean) * 100
        if pct <= -0.5 {
            return String(format: "%.1f%% below mean target", abs(pct))
        }
        if pct >= 0.5 {
            return String(format: "%.1f%% above mean target", pct)
        }
        return "At mean target"
    }

    static func formatShares(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    static func formatCompactUSD(_ value: Double) -> String {
        if abs(value) >= 1_000_000_000 {
            return String(format: "$%.1fB", value / 1_000_000_000)
        }
        if abs(value) >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        }
        if abs(value) >= 1_000 {
            return String(format: "$%.0fK", value / 1_000)
        }
        return CurrencyFormatter.usd(value, fractionDigits: 0)
    }

    static func formatActionDate(_ value: String) -> String {
        DateFormatters.abbreviatedDay(from: value)
    }

    static func formatRatingActionLine(_ action: AnalystRatingAction) -> String {
        var parts = [action.firm, action.toGrade]
        if let from = action.fromGrade, !from.isEmpty {
            parts.insert("from \(from)", at: 1)
        }
        if let verb = action.action, !verb.isEmpty {
            parts.append("(\(verb))")
        }
        return parts.joined(separator: " · ")
    }

    static func attribution(dataAsOf: String?) -> String {
        if let dataAsOf, !dataAsOf.isEmpty {
            return "Source: Yahoo Finance · \(DateFormatters.abbreviatedDay(from: dataAsOf))"
        }
        return "Source: Yahoo Finance"
    }
}

enum EarningsSelection {
    /// Prefer a reported quarter; avoid auto-opening detail for future or estimate-only rows.
    static func preferredHistoryEvent(from response: EarningsListResponse) -> EarningsEvent? {
        if let upcoming = response.upcoming {
            return upcoming
        }

        let today = Calendar.current.startOfDay(for: Date())
        if let reported = response.history.first(where: { event in
            guard let date = DateFormatters.parse(String(event.reportDate.prefix(10))) else {
                return false
            }
            let hasActuals = event.epsActual != nil
                || (event.beatLabel != nil && event.beatLabel != "pending")
            return date <= today && hasActuals
        }) {
            return reported
        }

        return response.history.first
    }

    static func shouldLoadDetail(for event: EarningsEvent) -> Bool {
        if event.isUpcoming { return false }
        if event.beatLabel == "pending" { return false }
        if event.epsActual == nil, event.beatLabel == nil { return false }
        return true
    }
}

enum EarningsFormatters {
    static func beatLabel(_ label: String?) -> String {
        switch label {
        case "beat": "Beat"
        case "miss": "Miss"
        case "inline": "Inline"
        case "pending": "Pending"
        default: "—"
        }
    }

    static func metricItems(for event: EarningsEvent) -> [(label: String, value: String)] {
        var items: [(label: String, value: String)] = [
            ("EPS actual", formatOptional(event.epsActual)),
            ("EPS est.", formatOptional(event.epsEstimate)),
        ]
        if let surprise = event.epsSurprisePct {
            items.append(("Surprise", String(format: "%+.1f%%", surprise)))
        }
        return Array(items.prefix(3))
    }

    static func formatOptional(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    static func formatReportDate(_ iso: String) -> String {
        DateFormatters.display(from: iso)
    }
}
