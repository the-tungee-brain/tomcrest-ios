import Foundation

struct StrategyFlowNode: Identifiable {
    let id: String
    let title: String
    let caption: String
}

struct StrategyFlowDefinition {
    let strategyId: String
    var repeats = false
    let nodes: [StrategyFlowNode]
}

enum StrategyFlows {
    static func flow(for strategyId: String) -> StrategyFlowDefinition? {
        flows[strategyId]
    }

    private static let flows: [String: StrategyFlowDefinition] = [
        "wheel": StrategyFlowDefinition(
            strategyId: "wheel",
            repeats: true,
            nodes: [
                StrategyFlowNode(id: "pick-symbol", title: "Pick a stock", caption: "Choose names you would be happy to own long term."),
                StrategyFlowNode(id: "sell-put", title: "Sell cash-secured put", caption: "Collect premium while waiting to buy at your strike."),
                StrategyFlowNode(id: "own-shares", title: "Own the shares", caption: "Get assigned or buy shares if the put is exercised."),
                StrategyFlowNode(id: "sell-call", title: "Sell covered call", caption: "Earn income on shares until called away or expired."),
            ]
        ),
        "csp-income": StrategyFlowDefinition(
            strategyId: "csp-income",
            nodes: [
                StrategyFlowNode(id: "pick-symbol", title: "Pick a stock", caption: "Focus on liquid names you would buy at a lower price."),
                StrategyFlowNode(id: "sell-put", title: "Sell cash-secured put", caption: "Set aside cash and collect premium upfront."),
                StrategyFlowNode(id: "manage", title: "Manage the position", caption: "Let expire, close early, or take assignment."),
                StrategyFlowNode(id: "repeat", title: "Re-deploy cash", caption: "Open the next put when capital is free again."),
            ]
        ),
        "covered-call": StrategyFlowDefinition(
            strategyId: "covered-call",
            nodes: [
                StrategyFlowNode(id: "own-shares", title: "Own 100+ shares", caption: "Start with stock you already hold or plan to keep."),
                StrategyFlowNode(id: "sell-call", title: "Sell covered call", caption: "Cap upside in exchange for premium income."),
                StrategyFlowNode(id: "outcome", title: "Expiration or assignment", caption: "Shares called away, or sell another call."),
                StrategyFlowNode(id: "repeat", title: "Repeat on shares", caption: "Keep writing calls while you hold the underlying."),
            ]
        ),
        "dividend": StrategyFlowDefinition(
            strategyId: "dividend",
            nodes: [
                StrategyFlowNode(id: "pick-dividend", title: "Pick dividend payers", caption: "Prioritize yield, payout safety, and business quality."),
                StrategyFlowNode(id: "build", title: "Build positions", caption: "Buy in sizes that match your diversification rules."),
                StrategyFlowNode(id: "collect", title: "Collect income", caption: "Reinvest dividends or take them as cash flow."),
                StrategyFlowNode(id: "monitor", title: "Monitor fundamentals", caption: "Watch payout ratio, growth, and sector balance."),
            ]
        ),
        "etf-core": StrategyFlowDefinition(
            strategyId: "etf-core",
            nodes: [
                StrategyFlowNode(id: "allocate", title: "Set target allocation", caption: "Define stock/bond mix and core ETF weights."),
                StrategyFlowNode(id: "buy", title: "Buy the core ETFs", caption: "Fund positions toward your target weights."),
                StrategyFlowNode(id: "rebalance", title: "Rebalance over time", caption: "When you're off target, trim what's up and buy what's down."),
                StrategyFlowNode(id: "hold", title: "Stay the course", caption: "Keep contributions steady and review on a schedule."),
            ]
        ),
    ]
}
