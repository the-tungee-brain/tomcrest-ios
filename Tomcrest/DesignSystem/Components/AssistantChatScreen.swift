import SwiftUI

/// Full-screen assistant layout used inside the global sheet.
struct AssistantChatScreen: View {
    @Environment(AccountContext.self) private var account
    @FocusState private var inputFocused: Bool

    let emptyMessage: String
    let inputPlaceholder: String
    let suggestedPrompts: [String]
    let messages: [ChatMessage]
    @Binding var inputText: String
    let canSend: Bool
    let isLoading: Bool
    let onSend: () -> Void
    let onSendPrompt: (String) -> Void
    var onClearChat: (() -> Void)? = nil
    var onShowHistory: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if messages.isEmpty {
                        Text(emptyMessage)
                            .font(AppTypography.bodySecondary)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(3)
                            .padding(.vertical, 4)
                    } else {
                        ChatMessageList(
                            messages: messages,
                            isLoading: isLoading,
                            onSendPrompt: onSendPrompt
                        )
                    }

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppColors.accent)
                            Text("Thinking…")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                        .padding(.vertical, 4)
                    }

                    if messages.isEmpty, !suggestedPrompts.isEmpty {
                        SuggestedPromptChips(
                            prompts: suggestedPrompts,
                            disabled: isLoading,
                            onSelect: onSendPrompt
                        )
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            Divider().overlay(AppColors.separator)

            ChatComposerBar(
                placeholder: inputPlaceholder,
                text: $inputText,
                canSend: canSend,
                isLoading: isLoading,
                inputFocused: $inputFocused,
                onSend: onSend
            )
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 12)
            .background(AppColors.secondaryBackground.opacity(0.95))
        }
        .background(AppColors.background)
    }
}
