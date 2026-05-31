import SwiftUI

struct PortfolioStrategyNudge: View {
    var onStart: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Finish strategy setup", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)

            Text("Pick a playbook, set preferences, and add symbols so Today can guide your next moves.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)

            HStack(spacing: 10) {
                Button("Start onboarding", action: onStart)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.onAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)

                Button("Open settings", action: onOpenSettings)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accentMuted.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PortfolioOnboardingCard: View {
    let schwabConnected: Bool
    let hasPositions: Bool
    let hasUsedAssistant: Bool
    var onConnectSchwab: () -> Void
    var onDismiss: () -> Void

    private var coreComplete: Bool {
        schwabConnected && hasPositions && hasUsedAssistant
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Getting started")
                    .font(AppTypography.bodySecondary.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Spacer()
                Button("Dismiss", action: onDismiss)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .buttonStyle(.plain)
            }

            onboardingStep("Connect Schwab", done: schwabConnected, actionTitle: "Open Settings", action: onConnectSchwab)
            onboardingStep("Review holdings", done: hasPositions)
            onboardingStep("Ask the assistant", done: hasUsedAssistant)

            if coreComplete {
                Text("You're set — explore research or run portfolio analysis anytime.")
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
        .appPanel(subtle: true)
    }

    @ViewBuilder
    private func onboardingStep(
        _ title: String,
        done: Bool,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? AppColors.success : AppColors.tertiaryLabel)
            Text(title)
                .font(.caption)
                .foregroundStyle(done ? AppColors.secondaryLabel : AppColors.label)
            Spacer()
            if !done, let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .buttonStyle(.plain)
            }
        }
    }
}

struct ResearchOnboardingCard: View {
    let hasOpenedSymbol: Bool
    let hasWatchlist: Bool
    let usedChat: Bool
    var onDismiss: () -> Void

    private var completedCount: Int {
        [hasOpenedSymbol, hasWatchlist, usedChat].filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Research")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .textCase(.uppercase)
                    Text("Explore any public company")
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text("\(completedCount) of 3 complete")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                Spacer()
                Button("Dismiss", action: onDismiss)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .buttonStyle(.plain)
            }

            checklistRow(
                "Search ticker or company name",
                description: "Open a symbol from search to view its research hub.",
                icon: "magnifyingglass",
                done: hasOpenedSymbol
            )
            checklistRow(
                "Save to your watchlist",
                description: "Star a symbol to track it on Research.",
                icon: "star",
                done: hasWatchlist
            )
            checklistRow(
                "Ask the assistant",
                description: "On a symbol page, use quick prompts or type a question.",
                icon: "message",
                done: usedChat
            )
        }
        .appPanel(subtle: true)
    }

    private func checklistRow(
        _ title: String,
        description: String,
        icon: String,
        done: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(done ? AppColors.success : AppColors.tertiaryLabel)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.label)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.insetSurface.opacity(done ? 0.85 : 0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(done ? AppColors.accentHighlight.opacity(0.3) : AppColors.separator, lineWidth: 1)
        }
    }
}
