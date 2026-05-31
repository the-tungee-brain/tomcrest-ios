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
