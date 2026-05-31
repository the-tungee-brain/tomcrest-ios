import SwiftUI

/// Inset journey checklist — lives inside the strategy panel, not a second card.
struct StrategyJourneySection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        if viewModel.isLoadingStrategy, viewModel.strategyJourney == nil {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(AppColors.accent)
                Text("Loading checklist…")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        } else if let journey = viewModel.strategyJourney {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView(value: journey.completionPct, total: 100)
                    .tint(AppColors.accent)

                AppGroupedList {
                    ForEach(sortedSteps(journey)) { step in
                        JourneyStepRow(
                            step: step,
                            isUpdating: viewModel.updatingJourneyStepId == step.stepId,
                            onComplete: {
                                Task { await viewModel.completeJourneyStep(step.stepId) }
                            }
                        )
                        if step.id != sortedSteps(journey).last?.id {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }

    private func sortedSteps(_ journey: UserStrategyJourney) -> [JourneyStep] {
        journey.steps.sorted { $0.order < $1.order }
    }
}

private struct JourneyStepRow: View {
    let step: JourneyStep
    let isUpdating: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: statusIcon)
                .font(.body)
                .foregroundStyle(statusColor)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(AppColors.label)
                Text(step.description)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if canComplete {
                Button(isUpdating ? "…" : "Done") {
                    onComplete()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(isUpdating)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .opacity(step.status == "locked" ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }

    private var canComplete: Bool {
        step.status == "available" || step.status == "in-progress"
    }

    private var statusIcon: String {
        switch step.status {
        case "completed": "checkmark.circle.fill"
        case "skipped": "arrow.uturn.forward.circle.fill"
        case "in-progress": "circle.dotted"
        case "available": "circle"
        default: "lock.fill"
        }
    }

    private var statusColor: Color {
        switch step.status {
        case "completed", "skipped": AppColors.success
        case "in-progress", "available": AppColors.accent
        default: AppColors.secondaryLabel
        }
    }
}
