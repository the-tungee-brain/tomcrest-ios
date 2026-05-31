import Foundation

struct NewsHeadline: Decodable, Identifiable {
    var id: String { "\(headline)-\(datetime)" }
    let headline: String
    let summary: String?
    let source: String
    let datetime: String
    let url: String?
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
}

struct FundamentalMetric: Decodable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let note: String?
}

struct FinancialStrength: Decodable {
    let rating: String
    let score: Int
    let headline: String
    let strengths: [String]
    let risks: [String]
}

struct FundamentalsOverview: Decodable {
    let atAGlance: String?
    let valuationTake: String?
    let strengths: [String]?
    let concerns: [String]?
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
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = parser.date(from: String(iso.prefix(10))) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return iso
    }
}
