import SwiftUI

struct PortfolioAssistantSheet: View {
    @Environment(AccountContext.self) private var account
    @Environment(AssistantPresenter.self) private var assistant
    @Environment(AppBrowserRouter.self) private var browser
    @Bindable var viewModel: PortfolioViewModel

    private let suggestedPrompts = [
        "What should I focus on today?",
        "Where is my portfolio concentrated?",
        "Any risks I should watch?",
    ]

    var body: some View {
        NavigationStack {
            AssistantChatScreen(
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
                onSend: {
                    Task { await viewModel.sendChatMessage(model: account.effectiveChatModel) }
                },
                onSendPrompt: { prompt in
                    Task { await viewModel.sendFollowUpPrompt(prompt, model: account.effectiveChatModel) }
                },
                onClearChat: { viewModel.clearChat() },
                onShowHistory: {
                    Task {
                        await viewModel.loadChatSessions()
                        viewModel.showChatHistory = true
                    }
                }
            )
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        assistant.dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button("History") {
                            Task {
                                await viewModel.loadChatSessions()
                                viewModel.showChatHistory = true
                            }
                        }
                        Button("Clear") {
                            viewModel.clearChat()
                        }
                        .disabled(viewModel.chatMessages.isEmpty || viewModel.chatLoading)
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .appInAppBrowser(browser)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $viewModel.showChatHistory) {
            AppNavigationCanvasStack {
                ChatSessionHistorySheet(
                    sessions: viewModel.chatSessions.filter {
                        ($0.title ?? "").hasPrefix("Portfolio:")
                    },
                    isLoading: viewModel.chatSessionsLoading,
                    onSelect: { session in
                        Task { await viewModel.openChatSession(session) }
                    },
                    onNewChat: {
                        viewModel.startNewChat()
                        viewModel.showChatHistory = false
                    },
                    onDelete: { session in
                        await viewModel.deleteChatSession(session)
                    }
                )
            }
        }
        .onAppear {
            applyPendingActionIfNeeded()
        }
    }

    private func applyPendingActionIfNeeded() {
        guard let action = assistant.consumePendingAction() else { return }
        if action.sendImmediately {
            Task { await viewModel.sendFollowUpPrompt(action.prompt, model: account.effectiveChatModel) }
        } else {
            viewModel.updateChatInput(action.prompt)
        }
    }
}
