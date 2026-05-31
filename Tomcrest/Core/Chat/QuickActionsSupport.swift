import Foundation

struct QuickActionDefinition: Identifiable {
    let id: String
    let label: String
    let apiAction: String?
    let prompt: ((String) -> String)?

    init(id: String, label: String, apiAction: String? = nil, prompt: ((String) -> String)? = nil) {
        self.id = id
        self.label = label
        self.apiAction = apiAction
        self.prompt = prompt
    }
}

enum QuickActionMode: Equatable {
    case portfolio
    case position(String)
    case options(String)
    case research(String)
}

enum QuickActionsSupport {
    static let portfolioTarget = "my portfolio"

    static let portfolioActions: [QuickActionDefinition] = [
        QuickActionDefinition(id: "portfolio-review", label: "Analyze", apiAction: "free-form") { target in
            "Analyze \(target)."
        },
        QuickActionDefinition(id: "daily-summary", label: "Daily summary", apiAction: "daily summary") { target in
            "Give me a concise daily summary of \(target) — what moved, what's at risk, and the one thing I should do today."
        },
        QuickActionDefinition(id: "risk-check", label: "Risk check", apiAction: "risk check") { target in
            "What are the biggest risks in \(target) right now — concentration, options, macro, and earnings?"
        },
        QuickActionDefinition(id: "concentration-check", label: "Concentration", apiAction: "concentration check") { target in
            "Check concentration in \(target). Flag anything above 15–20% and suggest specific trims if needed."
        },
        QuickActionDefinition(id: "tax-angle", label: "Tax angle", apiAction: "tax angle") { target in
            "What tax considerations apply to \(target) — gains, losses, wash sales, and whether to harvest anything now?"
        },
        QuickActionDefinition(id: "what-changed", label: "What changed", apiAction: "what changed") { target in
            "What changed in \(target) since my last snapshot — positions, weights, and any new risks?"
        },
        QuickActionDefinition(id: "assignment-risk", label: "Assignment risk", apiAction: "assignment risk") { target in
            "Review assignment and call-away risk in \(target) over the next two weeks. For each short option, say roll, close, or hold."
        },
    ]

    static let positionActions: [QuickActionDefinition] = [
        QuickActionDefinition(id: "position-review", label: "Analyze", apiAction: "free-form") { target in
            "Analyze my \(target) position."
        },
    ] + portfolioActions.filter { action in
        !["concentration-check", "portfolio-review", "assignment-risk"].contains(action.id)
    }

    static let optionsActions: [QuickActionDefinition] = [
        QuickActionDefinition(id: "options-review", label: "Analyze options", apiAction: "free-form") { target in
            "Analyze my \(target) option positions — rolls, assignment risk, and what to do next."
        },
        QuickActionDefinition(id: "assignment-risk", label: "Assignment risk", apiAction: "assignment risk") { target in
            "Review assignment and call-away risk in \(target) over the next two weeks. For each short option, say roll, close, or hold."
        },
        QuickActionDefinition(id: "roll-review", label: "Roll review", prompt: { target in
            "Review roll opportunities for my \(target) options. For each short leg, suggest roll targets with strike, expiration, and rationale."
        }),
        QuickActionDefinition(id: "tax-angle", label: "Tax angle", apiAction: "tax angle") { target in
            "What tax considerations apply to my \(target) options — gains, losses, and whether to harvest or roll for tax efficiency?"
        },
    ]

    static let researchActions: [QuickActionDefinition] = [
        QuickActionDefinition(id: "bull-bear-case", label: "Bull/bear case", prompt: { target in
            "Summarize the bull case and bear case for \(target) in plain English — 3 bullets each, then which side the data favors today."
        }),
        QuickActionDefinition(id: "key-risks", label: "Key risks", prompt: { target in
            "What are the top 3 business and market risks for \(target) over the next 6–12 months, and what would show up in the stock first?"
        }),
        QuickActionDefinition(id: "competitive-moat", label: "Competitive moat", prompt: { target in
            "How durable is \(target)'s competitive moat versus its main peers, and where is it most vulnerable?"
        }),
        QuickActionDefinition(id: "earnings-preview", label: "Earnings preview", prompt: { target in
            "What should I watch in the next earnings report for \(target) — key metrics, guidance, and how the stock might react?"
        }),
    ]

    static func actions(for mode: QuickActionMode) -> [QuickActionDefinition] {
        switch mode {
        case .portfolio:
            return portfolioActions
        case let .position(symbol):
            return positionActions
        case let .options(symbol):
            _ = symbol
            return optionsActions
        case let .research(symbol):
            _ = symbol
            return researchActions
        }
    }

    static func target(for mode: QuickActionMode) -> String {
        switch mode {
        case .portfolio:
            return portfolioTarget
        case let .position(symbol), let .options(symbol), let .research(symbol):
            return symbol.uppercased()
        }
    }

    static func formatMessage(actionId: String, target: String) -> String {
        if let action = find(actionId) {
            if let prompt = action.prompt {
                return prompt(target)
            }
            if let apiAction = action.apiAction, apiAction == "free-form" {
                return action.label
            }
        }
        return IntelligenceHelpers.quickActionMessage(actionId: actionId, symbol: target)
    }

    static func apiAction(for actionId: String) -> String {
        find(actionId)?.apiAction ?? actionId.replacingOccurrences(of: "-", with: " ")
    }

    static func usesStructuredAnalyze(_ actionId: String) -> Bool {
        actionId == "position-review" || actionId == "portfolio-review"
    }

    static func isPromptOnly(_ actionId: String) -> Bool {
        guard let action = find(actionId) else { return false }
        return action.prompt != nil && action.apiAction == nil
    }

    private static func find(_ actionId: String) -> QuickActionDefinition? {
        (portfolioActions + positionActions + optionsActions + researchActions)
            .first { $0.id == actionId }
    }
}
