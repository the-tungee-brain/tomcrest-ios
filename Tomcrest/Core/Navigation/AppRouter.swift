import Foundation

struct PendingSymbolResearch: Equatable {
    let symbol: String
    var tab: ResearchTab?
    var moreDestination: ResearchMoreDestination?
    var backtestSection: BacktestExploreSection?
    var wheelBacktestQuery: WheelBacktestQuery?
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .portfolio
    var settingsFocus: SettingsFocus?
    var showGlobalSymbolSearch = false
    var pendingSymbolResearch: PendingSymbolResearch?
    var showStrategyOnboarding = false

    func openSymbol(_ symbol: String, tab: ResearchTab? = nil, more: ResearchMoreDestination? = nil) {
        pendingSymbolResearch = PendingSymbolResearch(
            symbol: symbol.uppercased(),
            tab: tab,
            moreDestination: more
        )
        selectedTab = .research
    }

    func openWheelBacktest(symbol: String, query: WheelBacktestQuery) {
        pendingSymbolResearch = PendingSymbolResearch(
            symbol: symbol.uppercased(),
            tab: .more,
            moreDestination: .tools,
            backtestSection: .wheel,
            wheelBacktestQuery: query
        )
        selectedTab = .research
    }

    func openStrategyOnboarding() {
        showStrategyOnboarding = true
        selectedTab = .portfolio
    }

    func openSettingsStrategy() {
        settingsFocus = .strategy
        selectedTab = .settings
    }
}
