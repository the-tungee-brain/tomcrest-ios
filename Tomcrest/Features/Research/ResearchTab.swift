import Foundation

enum ResearchTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case news
    case earnings
    case dividends
    case fundamentals

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Overview"
        case .news: "News"
        case .earnings: "Earnings"
        case .dividends: "Dividends"
        case .fundamentals: "Fundamentals"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .news: "newspaper.fill"
        case .earnings: "chart.line.uptrend.xyaxis"
        case .dividends: "dollarsign.circle.fill"
        case .fundamentals: "tablecells.fill"
        }
    }

    /// Mirrors web `ResearchTabBar.tabsForAssetType` — hide irrelevant tabs per asset class.
    static func tabs(for assetType: String?) -> [ResearchTab] {
        let normalized = assetType?.uppercased() ?? "STOCK"
        var result: [ResearchTab] = [.overview, .news]

        switch normalized {
        case "ETF", "MUTUAL_FUND", "INDEX":
            result.append(.dividends)
            result.append(.fundamentals)
        case "STOCK", "ADR":
            result.append(.earnings)
            result.append(.dividends)
            result.append(.fundamentals)
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
