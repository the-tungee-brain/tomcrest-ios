import Foundation

/// Research tab navigation path — single stack, no nested NavigationStack.
enum ResearchRoute: Hashable {
    case watchlist
    case momentumBreakoutAlerts
    case symbol(TickerSymbolItem)
    case symbolHub(TickerSymbolItem, SymbolResearchDestination)
}

/// Push destinations from symbol overview — one screen per hub, lazy-loaded on navigation.
enum SymbolResearchDestination: Hashable {
    case analysis
    case business
    case metrics
    case news
    case financials
    case portfolio
    case income
    case tools
    case composition

    var navigationTitle: String {
        switch self {
        case .analysis: "Analysis"
        case .business: "Business"
        case .metrics: "Metrics"
        case .news: "News"
        case .financials: "Financials"
        case .portfolio: "Positions"
        case .income: "Income"
        case .tools: "Tools"
        case .composition: "Composition"
        }
    }

    var researchTab: ResearchTab {
        switch self {
        case .analysis: .analysis
        case .business: .business
        case .metrics: .metrics
        case .news: .news
        case .financials: .financials
        case .portfolio, .income, .tools, .composition: .more
        }
    }

    var moreDestination: ResearchMoreDestination? {
        switch self {
        case .portfolio: .portfolio
        case .income: .income
        case .tools: .tools
        case .composition: .composition
        default: nil
        }
    }

    static func from(tab: ResearchTab, more: ResearchMoreDestination?) -> SymbolResearchDestination? {
        switch (tab, more) {
        case (.overview, nil):
            return nil
        case (.analysis, _):
            return .analysis
        case (.business, _):
            return .business
        case (.metrics, _):
            return .metrics
        case (.news, _):
            return .news
        case (.financials, _):
            return .financials
        case (.more, .portfolio):
            return .portfolio
        case (.more, .options):
            return nil
        case (.more, .income):
            return .income
        case (.more, .tools):
            return .tools
        case (.more, .composition):
            return .composition
        case (.more, nil):
            return nil
        default:
            return nil
        }
    }

    static func rows(assetType: String?, availableTabs: [ResearchTab]) -> [SymbolResearchDestination] {
        var items: [SymbolResearchDestination] = []

        if availableTabs.contains(.analysis) { items.append(.analysis) }
        let normalized = assetType?.uppercased() ?? "STOCK"
        if availableTabs.contains(.analysis),
           normalized != "ETF",
           normalized != "MUTUAL_FUND",
           normalized != "INDEX" {
            items.append(.business)
        }
        if availableTabs.contains(.metrics) { items.append(.metrics) }
        if availableTabs.contains(.news) { items.append(.news) }
        if availableTabs.contains(.financials) { items.append(.financials) }

        if availableTabs.contains(.more) {
            items.append(contentsOf: ResearchMoreDestination.destinations(
                for: assetType,
                includesOptions: true
            ).compactMap { more in
                switch more {
                case .portfolio: .portfolio
                case .options: nil
                case .income: .income
                case .tools: .tools
                case .composition: .composition
                }
            })
        }

        return items
    }
}

/// Backward-compatible alias for watchlist navigation links.
typealias ResearchDestination = ResearchRoute
