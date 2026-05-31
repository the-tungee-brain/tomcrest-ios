import SwiftUI

struct ChatModelPicker: View {
    @Environment(AccountContext.self) private var account
    /// Plain text style for embedding in chat composer — no capsule chrome.
    var compact = false

    @State private var showsOptions = false

    var body: some View {
        Button {
            showsOptions = true
        } label: {
            triggerLabel
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showsOptions) {
            ChatModelOptionsSheet(isPresented: $showsOptions)
        }
        .accessibilityLabel("Chat model, \(account.selectedChatModelLabel)")
    }

    @ViewBuilder
    private var triggerLabel: some View {
        if compact {
            HStack(spacing: 4) {
                Text(account.selectedChatModelLabel)
                    .font(.caption2)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(AppColors.tertiaryLabel)
        } else {
            HStack(spacing: 6) {
                Text(account.selectedChatModelLabel)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(AppColors.secondaryLabel)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.secondaryFill)
            .clipShape(Capsule())
        }
    }
}

private struct ChatModelOptionsSheet: View {
    @Environment(AccountContext.self) private var account
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(account.chatModelGroups().enumerated()), id: \.offset) { _, group in
                    Section(group.label) {
                        ForEach(group.options) { option in
                            let locked = !account.isModelAllowed(option.id)
                            Button {
                                guard !locked else { return }
                                account.selectChatModel(option.id)
                                isPresented = false
                            } label: {
                                ChatModelOptionRow(
                                    option: option,
                                    isSelected: option.id == account.effectiveChatModel,
                                    isLocked: locked
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(locked)
                            .listRowBackground(AppColors.secondaryBackground)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("AI model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(AppColors.accentHighlight)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct ChatModelOptionRow: View {
    let option: ChatModelDefinition
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.id)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isLocked ? AppColors.tertiaryLabel : AppColors.label)
                Text(option.description)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            Group {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                }
            }
            .frame(width: 20, alignment: .trailing)
            .padding(.top, 2)
        }
        .contentShape(Rectangle())
    }
}
