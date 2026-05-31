import Foundation

struct TaxAlertItem: Identifiable {
    let id: String
    let label: String
    let reason: String
    let symbol: String?
    let actionId: String
}

enum IntelligenceHelpers {
    static func isTaxAction(_ action: String) -> Bool {
        action.lowercased().contains("tax")
    }

    static func isWashSaleText(_ text: String) -> Bool {
        text.lowercased().contains("wash sale")
    }

    static func isTaxAlert(_ alert: ProactiveAlert) -> Bool {
        isTaxAction(alert.action) || isWashSaleText(alert.reason)
    }

    static func suggestedActionToQuickActionId(_ action: String) -> String {
        let normalized = action
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        let aliases = [
            "tax-angle": "tax-angle",
            "what-changed": "what-changed",
            "risk-check": "risk-check",
            "daily-summary": "daily-summary",
            "assignment-risk": "assignment-risk",
            "concentration-check": "concentration-check",
        ]

        return aliases[normalized] ?? normalized
    }

    static func alertToQuickActionId(_ alert: ProactiveAlert) -> String {
        suggestedActionToQuickActionId(alert.action)
    }

    static func dedupeAlerts(_ alerts: [ProactiveAlert]) -> [ProactiveAlert] {
        var seen = Set<String>()
        var result: [ProactiveAlert] = []

        for alert in alerts.sorted(by: { $0.priority < $1.priority }) {
            let key = "\(alert.action):\(alert.symbol ?? "")"
            guard seen.insert(key).inserted else { continue }
            result.append(alert)
        }

        return result
    }

    static func symbolAlerts(
        symbol: String,
        proactive: [ProactiveAlert],
        brief: PortfolioIntelligence?
    ) -> [ProactiveAlert] {
        let symbolUpper = symbol.uppercased()
        let merged = PortfolioAlerts.merged(proactive: proactive, brief: brief)
        return dedupeAlerts(
            merged.filter { alert in
                !isTaxAlert(alert) &&
                    alert.symbol?.uppercased() == symbolUpper
            }
        )
        .prefix(4)
        .map { $0 }
    }

    static func filterNonTaxSuggestedActions(
        _ actions: [SuggestedAnalysisAction]
    ) -> [SuggestedAnalysisAction] {
        actions.filter { action in
            !isTaxAction(action.action) && !isWashSaleText(action.reason)
        }
    }

    static func filterNonTaxAlerts(_ alerts: [ProactiveAlert]) -> [ProactiveAlert] {
        alerts.filter { !isTaxAlert($0) }
    }

    static func pickSuggestedActions(
        _ actions: [SuggestedAnalysisAction],
        limit: Int = 3
    ) -> [SuggestedAnalysisAction] {
        actions
            .sorted { $0.priority < $1.priority }
            .prefix(limit)
            .map { $0 }
    }

    static func collectTaxAlertItems(
        alerts: [ProactiveAlert],
        suggestedActions: [SuggestedAnalysisAction] = [],
        symbol: String? = nil
    ) -> [TaxAlertItem] {
        let symbolUpper = symbol?.uppercased()
        var items: [TaxAlertItem] = []
        var seen = Set<String>()

        func add(_ item: TaxAlertItem) {
            let key = "\(item.actionId):\(item.symbol ?? ""):\(String(item.reason.prefix(80)))"
            guard seen.insert(key).inserted else { return }
            items.append(item)
        }

        for alert in alerts {
            guard isTaxAction(alert.action) || isWashSaleText(alert.reason) else { continue }
            if let symbolUpper,
               let alertSymbol = alert.symbol?.uppercased(),
               alertSymbol != symbolUpper {
                continue
            }
            add(
                TaxAlertItem(
                    id: "alert-\(alert.action)-\(alert.symbol ?? "portfolio")",
                    label: alert.label,
                    reason: alert.reason,
                    symbol: alert.symbol,
                    actionId: alertToQuickActionId(alert)
                )
            )
        }

        for suggestion in suggestedActions {
            guard isTaxAction(suggestion.action) || isWashSaleText(suggestion.reason) else { continue }
            add(
                TaxAlertItem(
                    id: "suggestion-\(suggestion.action)-\(suggestion.priority)",
                    label: suggestion.label,
                    reason: suggestion.reason,
                    symbol: symbolUpper,
                    actionId: suggestedActionToQuickActionId(suggestion.action)
                )
            )
        }

        return items.sorted { lhs, rhs in
            let lhsWash = isWashSaleText(lhs.reason) ? 0 : 1
            let rhsWash = isWashSaleText(rhs.reason) ? 0 : 1
            return lhsWash < rhsWash
        }
    }

    static func quickActionMessage(actionId: String, symbol: String) -> String {
        let normalized = suggestedActionToQuickActionId(actionId)
        switch normalized {
        case "risk-check":
            return "What are the biggest risks in \(symbol) right now — concentration, options, macro, and earnings?"
        case "tax-angle":
            return "What tax considerations apply to \(symbol) — gains, losses, wash sales, and whether to harvest anything now?"
        case "what-changed":
            return "What changed in \(symbol) since my last snapshot — positions, weights, and any new risks?"
        case "daily-summary":
            return "Give me a concise daily summary of \(symbol) — what moved, what's at risk, and the one thing I should do today."
        case "assignment-risk":
            return "Review assignment and call-away risk in \(symbol) over the next two weeks. For each short option, say roll, close, or hold."
        case "concentration-check":
            return "Check concentration in \(symbol). Flag anything above 15–20% and suggest specific trims if needed."
        case "position-review":
            return "Analyze my \(symbol) position."
        case "portfolio-review":
            return "Analyze \(symbol)."
        default:
            return "\(normalized.replacingOccurrences(of: "-", with: " ").capitalized) for \(symbol)"
        }
    }

    static func sortSignalsBySeverity(_ signals: [IntelligenceSignal]) -> [IntelligenceSignal] {
        let order: [SignalSeverity: Int] = [.critical: 0, .warning: 1, .watch: 2, .info: 3]
        return signals.sorted { lhs, rhs in
            (order[lhs.severity] ?? 4) < (order[rhs.severity] ?? 4)
        }
    }

    static func portfolioTradeSuggestions(
        alerts: [ProactiveAlert],
        attentionQueue: [AttentionItem],
        taxItems: [TaxAlertItem],
        suggestedActions: [SuggestedAnalysisAction],
        limit: Int = 4
    ) -> [SuggestedAnalysisAction] {
        let useQueue = !attentionQueue.isEmpty
        let generalAlerts = useQueue ? [] : dedupeAlerts(filterNonTaxAlerts(alerts))

        var actionKeys = Set<String>()
        for item in taxItems {
            actionKeys.insert(item.actionId.lowercased())
        }
        for alert in generalAlerts {
            actionKeys.insert(alertToQuickActionId(alert).lowercased())
        }
        for item in attentionQueue {
            actionKeys.insert(item.action.lowercased())
        }

        return pickSuggestedActions(filterNonTaxSuggestedActions(suggestedActions), limit: limit)
            .filter { action in
                let key = suggestedActionToQuickActionId(action.action).lowercased()
                return !actionKeys.contains(key)
            }
    }

    static func countPortfolioAttentionItems(
        taxItems: [TaxAlertItem],
        alerts: [ProactiveAlert],
        attentionQueue: [AttentionItem],
        suggestedActions: [SuggestedAnalysisAction]
    ) -> Int {
        let useQueue = !attentionQueue.isEmpty
        let generalAlerts = useQueue ? [] : dedupeAlerts(filterNonTaxAlerts(alerts))
        let extraSuggestions = portfolioTradeSuggestions(
            alerts: alerts,
            attentionQueue: attentionQueue,
            taxItems: taxItems,
            suggestedActions: suggestedActions
        )
        return taxItems.count + (useQueue ? attentionQueue.count : generalAlerts.count) + extraSuggestions.count
    }
}

enum PositionMetrics {
    static func totalValue(_ positions: [Position]) -> Double {
        positions.reduce(0) { $0 + $1.marketValue }
    }

    static func totalOpenProfitLoss(_ positions: [Position]) -> Double {
        positions.reduce(0) { $0 + ($1.openProfitLoss ?? 0) }
    }

    static func totalDayProfitLoss(_ positions: [Position]) -> Double {
        positions.reduce(0) { $0 + $1.currentDayProfitLoss }
    }

    static func openProfitLossPct(_ positions: [Position]) -> Double? {
        var openPL: Double = 0
        var costBasis: Double = 0

        for position in positions {
            guard let legOpenPL = position.openProfitLoss else { continue }
            openPL += legOpenPL
            let legCost = position.marketValue - legOpenPL
            if legCost != 0 {
                costBasis += abs(legCost)
            }
        }

        guard costBasis > 0 else { return nil }
        return (openPL / costBasis) * 100
    }
}
