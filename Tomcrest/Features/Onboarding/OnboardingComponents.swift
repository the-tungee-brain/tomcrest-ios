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
    let openedSymbol: Bool
    let usedChat: Bool
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Research checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Spacer()
                Button("Dismiss", action: onDismiss)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .buttonStyle(.plain)
            }

            checklistRow("Open a symbol page", done: openedSymbol)
            checklistRow("Ask the research assistant", done: usedChat)
        }
        .padding(14)
        .appPanel(subtle: true)
    }

    private func checklistRow(_ title: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? AppColors.success : AppColors.tertiaryLabel)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.label)
        }
    }
}
