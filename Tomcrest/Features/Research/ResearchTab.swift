import Foundation

/// Top-level research destinations — six hubs instead of a flat list of 11+ tabs.
enum ResearchTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case analysis
    case metrics
    case news
    case financials
    case more

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Overview"
        case .analysis: "Analysis"
        case .metrics: "Metrics"
        case .news: "News"
        case .financials: "Financials"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "chart.line.uptrend.xyaxis"
        case .analysis: "sparkles"
        case .metrics: "gauge.with.dots.needle.67percent"
        case .news: "newspaper"
        case .financials: "doc.text"
        case .more: "ellipsis.circle"
        }
    }

    static func tabs(for assetType: String?) -> [ResearchTab] {
        let normalized = assetType?.uppercased() ?? "STOCK"

        switch normalized {
        case "ETF", "MUTUAL_FUND", "INDEX":
            return [.overview, .metrics, .news, .more]
        default:
            return [.overview, .analysis, .metrics, .news, .financials, .more]
        }
    }

    func metricsLabel(for assetType: String?) -> String {
        let normalized = assetType?.uppercased() ?? "STOCK"
        if normalized == "ETF" || normalized == "MUTUAL_FUND" {
            return "Fund metrics"
        }
        return "Metrics"
    }

    /// Maps legacy deep-link path segments to hub tabs + optional More destination.
    static func resolve(deepLink name: String) -> (tab: ResearchTab, more: ResearchMoreDestination?) {
        switch name.lowercased() {
        case "position", "positions", "options":
            return (.more, .portfolio)
        case "earnings", "dividends", "income":
            return (.more, .income)
        case "backtest", "wheel-backtest", "wheelbacktest":
            return (.more, .tools)
        case "composition":
            return (.more, .composition)
        case "business", "trend", "5d-trend":
            return (.analysis, nil)
        case "fundamentals":
            return (.metrics, nil)
        default:
            if let tab = ResearchTab(rawValue: name.lowercased()) {
                return (tab, nil)
            }
            return (.overview, nil)
        }
    }
}

/// Secondary screens reachable from the More hub.
enum ResearchMoreDestination: String, CaseIterable, Identifiable, Hashable {
    case portfolio
    case income
    case tools
    case composition

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portfolio: "Portfolio"
        case .income: "Income"
        case .tools: "Tools"
        case .composition: "Composition"
        }
    }

    var subtitle: String {
        switch self {
        case .portfolio: "Holdings, options, and activity"
        case .income: "Dividends and earnings history"
        case .tools: "Backtests and simulations"
        case .composition: "Holdings and sector breakdown"
        }
    }

    var systemImage: String {
        switch self {
        case .portfolio: "briefcase"
        case .income: "dollarsign.circle"
        case .tools: "chart.xyaxis.line"
        case .composition: "square.stack.3d.up"
        }
    }

    static func destinations(for assetType: String?, includesOptions: Bool) -> [ResearchMoreDestination] {
        let normalized = assetType?.uppercased() ?? "STOCK"

        switch normalized {
        case "ETF", "MUTUAL_FUND", "INDEX":
            return [.composition, .income, .tools]
        default:
            var items: [ResearchMoreDestination] = [.portfolio, .income, .tools]
            if includesOptions {
                _ = includesOptions
            }
            return items
        }
    }
}
