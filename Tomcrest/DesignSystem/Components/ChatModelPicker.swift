import SwiftUI

struct ChatModelPicker: View {
    @Environment(AccountContext.self) private var account
    /// Plain text style for embedding in chat composer — no capsule chrome.
    var compact = false

    var body: some View {
        Menu {
            ForEach(Array(account.chatModelGroups().enumerated()), id: \.offset) { _, group in
                Section(group.label) {
                    ForEach(group.options) { option in
                        let locked = account.requiresProModel(option.id) && account.plan?.isPaid != true
                        Button {
                            account.selectChatModel(option.id)
                        } label: {
                            if locked {
                                Label(option.label, systemImage: "lock.fill")
                            } else if option.id == account.effectiveChatModel {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                        .disabled(locked)
                    }
                }
            }
        } label: {
            if compact {
                HStack(spacing: 4) {
                    Text("Model · \(account.selectedChatModelLabel)")
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
        .accessibilityLabel("Chat model, \(account.selectedChatModelLabel)")
    }
}
