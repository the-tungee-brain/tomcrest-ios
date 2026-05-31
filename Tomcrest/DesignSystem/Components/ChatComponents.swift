import SwiftUI

/// Collapsible assistant header — plain disclosure row, no sparkle icon.
struct AssistantPanelHeader: View {
    let title: String
    let isExpanded: Bool
    let expandAccessibilityLabel: String
    let collapseAccessibilityLabel: String
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 8) {
                AppScreenSectionLabel(title: title)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? collapseAccessibilityLabel : expandAccessibilityLabel)
    }
}

/// Shared chat panel — collapsed by default; suggested prompts hide once a thread starts.
struct AppChatPanelContent: View {
    @Environment(AccountContext.self) private var account
    @FocusState private var inputFocused: Bool

    let title: String
    let isExpanded: Bool
    let expandAccessibilityLabel: String
    let collapseAccessibilityLabel: String
    let emptyMessage: String
    let inputPlaceholder: String
    let suggestedPrompts: [String]
    let messages: [ChatMessage]
    @Binding var inputText: String
    let canSend: Bool
    let isLoading: Bool
    let onToggle: () -> Void
    let onSend: () -> Void
    let onSendPrompt: (String) -> Void
    var onClearChat: (() -> Void)? = nil
    var onShowHistory: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                AssistantPanelHeader(
                    title: title,
                    isExpanded: isExpanded,
                    expandAccessibilityLabel: expandAccessibilityLabel,
                    collapseAccessibilityLabel: collapseAccessibilityLabel,
                    onToggle: onToggle
                )
                if onClearChat != nil || onShowHistory != nil {
                    Spacer(minLength: 0)
                    if let onShowHistory {
                        Button("History", action: onShowHistory)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.accentHighlight)
                    }
                    if let onClearChat {
                        Button("Clear", action: onClearChat)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.accentHighlight)
                            .disabled(messages.isEmpty || isLoading)
                            .opacity(messages.isEmpty || isLoading ? 0.45 : 1)
                    }
                }
            }

            if isExpanded {
                Group {
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
                }
                .transition(.opacity)

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

                // Prompts only before the first message — keeps active chats uncluttered.
                if messages.isEmpty, !suggestedPrompts.isEmpty {
                    SuggestedPromptChips(
                        prompts: suggestedPrompts,
                        disabled: isLoading,
                        onSelect: onSendPrompt
                    )
                }

                // Model + input on one composer row — fewer stacked controls.
                ChatComposerBar(
                    placeholder: inputPlaceholder,
                    text: $inputText,
                    canSend: canSend,
                    isLoading: isLoading,
                    inputFocused: $inputFocused,
                    onSend: onSend
                )
            }
        }
        .clipped()
        .appPanel(subtle: true)
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }
}

struct ChatComposerBar: View {
    let placeholder: String
    @Binding var text: String
    let canSend: Bool
    let isLoading: Bool
    var inputFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChatModelPicker(compact: true)

            HStack(alignment: .bottom, spacing: 10) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1 ... 4)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(AppColors.label)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: Layout.minTouchTarget, alignment: .leading)
                    .background(AppColors.secondaryFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.separator, lineWidth: 1)
                    }
                    .focused(inputFocused)
                    .disabled(isLoading)

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? AppColors.accent : AppColors.tertiaryLabel)
                }
                .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                .disabled(!canSend)
            }
        }
    }
}

struct ChatMessageList: View {
    let messages: [ChatMessage]
    let isLoading: Bool
    let onSendPrompt: (String) -> Void

    private var lastAssistantIndex: Int? {
        messages.lastIndex(where: { $0.role == .assistant })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                ChatBubble(
                    message: message,
                    isStreaming: isLoading && index == lastAssistantIndex && message.role == .assistant,
                    isLoading: isLoading,
                    showFollowUps: ChatFollowUpSuggestions.shouldShowFollowUps(
                        messages: messages,
                        messageIndex: index,
                        isLoading: isLoading
                    ),
                    onSendPrompt: onSendPrompt
                )
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var isStreaming = false
    var isLoading = false
    var showFollowUps = false
    let onSendPrompt: (String) -> Void

    private var followUpSuggestions: [ChatFollowUpSuggestion] {
        showFollowUps ? ChatFollowUpSuggestions.parseFollowUps(message.content) : []
    }

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 32) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Group {
                    if message.role == .assistant {
                        ConversationalMarkdownText(
                            content: message.content,
                            isStreaming: isStreaming
                        )
                    } else {
                        Text(message.content.isEmpty ? "…" : message.content)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.label)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? AppColors.accent.opacity(0.18) : AppColors.secondaryFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if message.role == .assistant, showFollowUps {
                    ChatFollowUpChips(
                        suggestions: followUpSuggestions,
                        disabled: isLoading,
                        onSelect: onSendPrompt
                    )
                }
            }
            .layoutPriority(1)
            if message.role == .assistant { Spacer(minLength: 32) }
        }
    }
}

struct ChatFollowUpChips: View {
    let suggestions: [ChatFollowUpSuggestion]
    var disabled = false
    let onSelect: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Follow up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .textCase(.uppercase)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 148), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(suggestions) { suggestion in
                        AppChip(title: suggestion.label) {
                            onSelect(suggestion.prompt)
                        }
                        .disabled(disabled)
                        .opacity(disabled ? 0.5 : 1)
                    }
                }
            }
        }
    }
}

struct SuggestedPromptChips: View {
    let prompts: [String]
    var disabled = false
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 148), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(prompts, id: \.self) { prompt in
                AppChip(title: prompt) {
                    onSelect(prompt)
                }
                .disabled(disabled)
                .opacity(disabled ? 0.5 : 1)
            }
        }
    }
}
