import Foundation

enum AppDeepLinks {
    @MainActor
    static func handle(_ url: URL, router: AppRouter) -> Bool {
        guard url.scheme?.lowercased() == "tomcrest" else { return false }

        let host = (url.host ?? "").lowercased()
        let pathParts = url.path.split(separator: "/").map(String.init)

        switch host {
        case "onboarding":
            router.openStrategyOnboarding()
            return true
        case "research":
            guard let symbol = pathParts.first, !symbol.isEmpty else { return false }
            let tabName = pathParts.count > 1 ? pathParts[1] : nil
            let tab = tabName.flatMap(ResearchTab.init(rawValue:))

            if tabName == "wheel-backtest" || tabName == "wheelBacktest" {
                let query = WheelBacktestShareSupport.parse(url: url, symbol: symbol)
                router.openWheelBacktest(symbol: symbol, query: query)
                return true
            }

            if tab == .backtest || tabName == "backtest" {
                router.pendingSymbolResearch = PendingSymbolResearch(
                    symbol: symbol.uppercased(),
                    tab: .backtest
                )
                router.selectedTab = .research
                return true
            }

            router.openSymbol(symbol, tab: tab)
            return true
        case "settings":
            if pathParts.first == "strategy" {
                router.openSettingsStrategy()
                return true
            }
            router.selectedTab = .settings
            return true
        default:
            return false
        }
    }
}

enum WheelBacktestShareSupport {
    static func webURL(for query: WheelBacktestQuery) -> URL? {
        var components = URLComponents(string: "https://tomcrest.com/research/\(query.symbol.uppercased())/wheel-backtest")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "years", value: String(query.years)),
            URLQueryItem(name: "dte", value: String(query.dteDays)),
            URLQueryItem(name: "maintain", value: query.maintainOneLot ? "1" : "0"),
        ]
        if query.callStrikeMode == "at_or_above_assignment" {
            items.append(URLQueryItem(name: "callFloor", value: "1"))
        }
        components?.queryItems = items
        return components?.url
    }

    static func appURL(for query: WheelBacktestQuery) -> URL? {
        var components = URLComponents()
        components.scheme = "tomcrest"
        components.host = "research"
        components.path = "/\(query.symbol.uppercased())/wheel-backtest"
        components.queryItems = [
            URLQueryItem(name: "years", value: String(query.years)),
            URLQueryItem(name: "dte", value: String(query.dteDays)),
            URLQueryItem(name: "maintain", value: query.maintainOneLot ? "1" : "0"),
            URLQueryItem(name: "callFloor", value: query.callStrikeMode == "at_or_above_assignment" ? "1" : "0"),
        ]
        return components.url
    }

    static func parse(url: URL, symbol: String) -> WheelBacktestQuery {
        var query = WheelBacktestQuery(symbol: symbol.uppercased())
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return query
        }

        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        if let years = value("years"), let parsed = Int(years) {
            query.years = parsed
        }
        if let dte = value("dte"), let parsed = Int(dte) {
            query.dteDays = WheelBacktestQuery.normalizeDteDays(parsed)
        }
        if let maintain = value("maintain") {
            query.maintainOneLot = maintain == "1"
        }
        if value("callFloor") == "1" {
            query.callStrikeMode = "at_or_above_assignment"
        }
        return query
    }
}
