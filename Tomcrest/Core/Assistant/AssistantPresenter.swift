import Foundation

struct AssistantPendingAction: Equatable {
    let prompt: String
    let sendImmediately: Bool
}

@MainActor
@Observable
final class AssistantPresenter {
    enum Scope: Equatable {
        case portfolio
        case symbol(String)
    }

    private(set) var isPresented = false
    private(set) var scope: Scope = .portfolio
    private var pendingAction: AssistantPendingAction?

    var isPortfolioPresented: Bool {
        isPresented && scope == .portfolio
    }

    func isSymbolPresented(_ symbol: String) -> Bool {
        isPresented && scope == .symbol(symbol.uppercased())
    }

    func openPortfolio(prompt: String? = nil, sendImmediately: Bool = false) {
        open(scope: .portfolio, prompt: prompt, sendImmediately: sendImmediately)
    }

    func openSymbol(_ symbol: String, prompt: String? = nil, sendImmediately: Bool = false) {
        open(scope: .symbol(symbol.uppercased()), prompt: prompt, sendImmediately: sendImmediately)
    }

    func dismiss() {
        isPresented = false
        pendingAction = nil
    }

    func consumePendingAction() -> AssistantPendingAction? {
        defer { pendingAction = nil }
        return pendingAction
    }

    private func open(scope: Scope, prompt: String?, sendImmediately: Bool) {
        self.scope = scope
        if let prompt {
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                pendingAction = AssistantPendingAction(
                    prompt: trimmed,
                    sendImmediately: sendImmediately
                )
            }
        }
        isPresented = true
    }
}
