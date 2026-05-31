import Foundation

enum ResearchTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case position
    case options
    case news
    case business
    case earnings
    case dividends
    case fundamentals
    case financials
    case composition
    case wheelBacktest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Overview"
        case .position: "Positions"
        case .options: "Options"
        case .news: "News"
        case .business: "Business"
        case .earnings: "Earnings"
        case .dividends: "Dividends"
        case .fundamentals: "Fundamentals"
        case .financials: "Financials"
        case .composition: "Composition"
        case .wheelBacktest: "Backtest"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .position: "briefcase.fill"
        case .options: "target"
        case .news: "newspaper.fill"
        case .business: "building.2.fill"
        case .earnings: "chart.line.uptrend.xyaxis"
        case .dividends: "dollarsign.circle.fill"
        case .fundamentals: "tablecells.fill"
        case .financials: "doc.text.fill"
        case .composition: "square.stack.3d.up.fill"
        case .wheelBacktest: "chart.xyaxis.line"
        }
    }

    static func tabs(
        for assetType: String?,
        primaryStrategy: String? = nil
    ) -> [ResearchTab] {
        let normalized = assetType?.uppercased() ?? "STOCK"
        var result: [ResearchTab] = [.overview, .position, .options, .news]

        switch normalized {
        case "ETF", "MUTUAL_FUND", "INDEX":
            result.removeAll { $0 == .options || $0 == .business }
            result.append(.dividends)
            result.append(.composition)
            result.append(.fundamentals)
        case "STOCK", "ADR":
            result.append(.dividends)
            result.append(.business)
            result.append(.earnings)
            result.append(.fundamentals)
            result.append(.financials)
            if primaryStrategy == "wheel" {
                result.append(.wheelBacktest)
            }
        default:
            result.append(.earnings)
            result.append(.dividends)
            result.append(.fundamentals)
        }

        return result
    }

    func fundamentalsLabel(for assetType: String?) -> String {
        let normalized = assetType?.uppercased() ?? "STOCK"
        if normalized == "ETF" || normalized == "MUTUAL_FUND" {
            return "Fund metrics"
        }
        return "Fundamentals"
    }
}
