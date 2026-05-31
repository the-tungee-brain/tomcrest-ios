import SwiftUI

struct PortfolioChatPanel: View {
    @Environment(AccountContext.self) private var account
    @Bindable var viewModel: PortfolioViewModel

    private let suggestedPrompts = [
        "What should I focus on today?",
        "Where is my portfolio concentrated?",
        "Any risks I should watch?",
    ]

    var body: some View {
        AppChatPanelContent(
            title: "Ask Tomcrest",
            isExpanded: viewModel.chatExpanded,
            expandAccessibilityLabel: "Expand portfolio assistant",
            collapseAccessibilityLabel: "Collapse portfolio assistant",
            emptyMessage: "Ask about holdings, risk, or where to deploy cash.",
            inputPlaceholder: "Ask about your portfolio…",
            suggestedPrompts: suggestedPrompts,
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
            onSelectPrompt: { viewModel.updateChatInput($0) }
        )
    }
}
