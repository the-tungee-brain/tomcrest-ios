import Foundation

/// Display-level tabs for the symbol research shell.
enum ResearchPrimaryTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case analysis
    case events
    case positions
    case options
    case more

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Overview"
        case .analysis: "Analysis"
        case .events: "Events"
        case .positions: "Positions"
        case .options: "Options"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "chart.line.uptrend.xyaxis"
        case .analysis: "sparkles"
        case .events: "calendar"
        case .positions: "briefcase"
        case .options: "target"
        case .more: "ellipsis.circle"
        }
    }

    static var visibleTabs: [ResearchPrimaryTab] {
        [.overview, .analysis, .events, .positions, .options, .more]
    }

    static func resolve(tab: ResearchTab, more: ResearchMoreDestination?) -> ResearchPrimaryTab {
        switch (tab, more) {
        case (.overview, _):
            return .overview
        case (.analysis, _):
            return .analysis
        case (.news, _):
            return .events
        case (.more, .portfolio):
            return .positions
        case (.more, .options):
            return .options
        default:
            return .more
        }
    }
}

/// Top-level research destinations — six hubs instead of a flat list of 11+ tabs.
enum ResearchTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case analysis
    case business
    case metrics
    case news
    case financials
    case more

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Overview"
        case .analysis: "Analysis"
        case .business: "Business"
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
        case .business: "building.2"
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
            return [.overview, .analysis, .metrics, .news, .more]
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
        case "position", "positions":
            return (.more, .portfolio)
        case "options":
            return (.more, .options)
        case "earnings", "dividends", "income":
            return (.more, .income)
        case "backtest", "wheel-backtest", "wheelbacktest":
            return (.more, .tools)
        case "composition":
            return (.more, .composition)
        case "business":
            return (.business, nil)
        case "trend", "5d-trend":
            return (.analysis, nil)
        case "fundamentals":
            return (.metrics, nil)
        case "events":
            return (.news, nil)
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
    case options
    case income
    case tools
    case composition

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portfolio: "Positions"
        case .options: "Options"
        case .income: "Income"
        case .tools: "Tools"
        case .composition: "Composition"
        }
    }

    var subtitle: String {
        switch self {
        case .portfolio: "Holdings, position guidance, and activity"
        case .options: "Options scorecards, rolls, and chain preview"
        case .income: "Dividends and earnings history"
        case .tools: "Backtests and simulations"
        case .composition: "Holdings and sector breakdown"
        }
    }

    var systemImage: String {
        switch self {
        case .portfolio: "briefcase"
        case .options: "target"
        case .income: "dollarsign.circle"
        case .tools: "chart.xyaxis.line"
        case .composition: "square.stack.3d.up"
        }
    }

    static func destinations(for assetType: String?, includesOptions: Bool) -> [ResearchMoreDestination] {
        let normalized = assetType?.uppercased() ?? "STOCK"

        switch normalized {
        case "ETF", "MUTUAL_FUND", "INDEX":
            return [.portfolio, .composition, .income, .tools]
        default:
            let items: [ResearchMoreDestination] = [.portfolio, .income, .tools]
            if includesOptions {
                _ = includesOptions
            }
            return items
        }
    }
}
