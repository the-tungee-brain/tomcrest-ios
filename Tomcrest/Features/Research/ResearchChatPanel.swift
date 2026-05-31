import SwiftUI

struct ResearchChatPanel: View {
    @Environment(AccountContext.self) private var account
    @Bindable var viewModel: SymbolOverviewViewModel

    var body: some View {
        AppChatPanelContent(
            title: "Ask about \(viewModel.symbol)",
            isExpanded: viewModel.chatExpanded,
            expandAccessibilityLabel: "Expand research assistant",
            collapseAccessibilityLabel: "Collapse research assistant",
            emptyMessage: "Ask about quality, risks, earnings, or valuation.",
            inputPlaceholder: "Ask about \(viewModel.symbol)…",
            suggestedPrompts: viewModel.suggestedPromptLabels,
            messages: viewModel.chatMessages,
            inputText: Binding(
                get: { viewModel.chatInput },
                set: { viewModel.updateChatInput($0) }
            ),
            canSend: viewModel.canSendChat,
            isLoading: viewModel.chatLoading,
            onToggle: { viewModel.toggleChatExpanded() },
            onSend: {
                Task { await viewModel.sendChatMessage(model: account.effectiveChatModel) }
            },
            onSelectPrompt: { label in
                if let prompt = viewModel.suggestedPrompt(for: label) {
                    viewModel.updateChatInput(prompt)
                }
            }
        )
    }
}
