import Foundation

enum StrategyPlaybookHelpers {
    static let wheelLikeStrategies: Set<String> = ["wheel", "csp-income", "covered-call"]

    static func symbols(from profile: UserInvestmentProfile?) -> [String] {
        StrategyFormSupport.symbols(from: profile)
    }

    static func isWheelLikeStrategy(_ strategyId: String?) -> Bool {
        guard let strategyId else { return false }
        return wheelLikeStrategies.contains(strategyId)
    }

    static func formatPlaybookTitle(
        strategyId: String,
        catalogItem: StrategyCatalogItem?
    ) -> String {
        if let title = catalogItem?.title, !title.isEmpty {
            return title
        }
        switch strategyId {
        case "wheel": return "Wheel strategy"
        case "csp-income": return "Cash-secured puts"
        case "covered-call": return "Covered calls"
        case "dividend": return "Dividend investing"
        case "etf-core": return "ETF core portfolio"
        default: return strategyId
        }
    }

    static func strategyIconName(for strategyId: String) -> String {
        switch strategyId {
        case "wheel": return "arrow.triangle.2.circlepath"
        case "csp-income", "dividend": return "dollarsign.circle"
        case "covered-call": return "chart.line.uptrend.xyaxis"
        case "etf-core": return "square.stack.3d.up"
        default: return "sparkles"
        }
    }

    static func primaryPlaybookAction(
        from recommendations: StrategyRecommendations?
    ) -> StrategyNextAction? {
        recommendations?.nextActions.first
    }

    static func actionTypeLabel(_ type: String) -> String {
        switch type {
        case "connect": return "Connect"
        case "research": return "Research"
        case "options": return "Options"
        case "monitor": return "Monitor"
        case "buy": return "Buy"
        case "rebalance": return "Rebalance"
        case "education": return "Learn"
        default: return "Action"
        }
    }

    static func playbookHoldBadge(_ status: StrategySymbolStatus) -> String {
        if status.statusLabel.lowercased().contains("partial lot") {
            return "Partial"
        }
        return status.held ? "Held" : "Not held"
    }

    static func symbolNeedsAttention(_ status: StrategySymbolStatus) -> Bool {
        (status.priority ?? 50) <= 2
    }

    static func wheelPhaseLabel(_ phase: String?) -> String {
        switch phase {
        case "ready-for-csp": return "Ready for CSP"
        case "short-put-open": return "Put open"
        case "assigned-shares": return "Shares held"
        case "short-call-open": return "Call open"
        case "complete-cycle": return "Cycle complete"
        case "pick-symbol": return "Pick symbol"
        default: return "On playbook"
        }
    }

    static func playbookActionAskable(_ action: StrategyNextAction) -> Bool {
        action.type != "connect" && action.type != "education"
    }

    static func playbookAskPrompt(for action: StrategyNextAction) -> String {
        let symbol = action.symbol?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let titleLower = action.title.lowercased()
        let reason = action.reason.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let symbol, !symbol.isEmpty else {
            return action.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Strategy playbook question"
                : action.title
        }

        switch action.type {
        case "research":
            if titleLower.contains("put") || titleLower.contains("csp") || titleLower.contains("wheel") {
                return "Would I be comfortable owning \(symbol) if assigned on a put for my strategy playbook?"
            }
            if titleLower.contains("dividend") {
                return "Should I hold \(symbol) as a dividend name on my strategy playbook?"
            }
            return "Should I hold \(symbol) for my strategy playbook?"
        case "options":
            if titleLower.contains("covered call") {
                return "I hold \(symbol) on my strategy playbook and I'm looking at writing a covered call. What strike and expiration would you suggest, and what assignment risk should I plan for?"
            }
            if titleLower.contains("csp") || titleLower.contains("put") {
                return "Would I be comfortable owning \(symbol) if assigned on a put for my strategy playbook?"
            }
            return "For \(symbol) on my strategy playbook: \(action.title.trimmingCharacters(in: .whitespacesAndNewlines)). What option trade would you consider next, and why?"
        case "monitor":
            let lead = "I have an open options position on \(symbol)."
            if !reason.isEmpty {
                return "\(lead) \(reason) What should I watch for, and when would you roll, close, or let it ride?"
            }
            return "\(lead) What should I watch for, and when would you roll, close, or let it ride?"
        case "buy":
            return "Should I build a position in \(symbol) for my strategy playbook?"
        case "rebalance":
            return "Review \(symbol) in my portfolio for my strategy playbook. Should I add, trim, or hold based on my targets?"
        default:
            let trimmed = action.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Strategy playbook question" : trimmed
        }
    }
}
