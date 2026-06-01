import SwiftUI

struct ResearchAssistantSheet: View {
    @Environment(AccountContext.self) private var account
    @Environment(AssistantPresenter.self) private var assistant
    @Bindable var viewModel: SymbolOverviewViewModel

    var body: some View {
        AppNavigationCanvasStack {
            AssistantChatScreen(
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
                onSend: {
                    Task { await viewModel.sendChatMessage(model: account.effectiveChatModel) }
                },
                onSendPrompt: { label in
                    let prompt = viewModel.suggestedPrompt(for: label) ?? label
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
            .navigationTitle(viewModel.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationCanvas()
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .sheet(isPresented: $viewModel.showChatHistory) {
            AppNavigationCanvasStack {
                ChatSessionHistorySheet(
                    sessions: viewModel.chatSessions.filter {
                        ($0.title ?? "").hasPrefix("Research:\(viewModel.symbol.uppercased()):")
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
