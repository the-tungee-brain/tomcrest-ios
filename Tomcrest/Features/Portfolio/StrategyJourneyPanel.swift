import SwiftUI

struct StrategyJourneyPanel: View {
    let strategyId: String
    let catalogItem: StrategyCatalogItem?
    var onOpenSettings: () -> Void

    @State private var isExpanded = !OnboardingStorage.isStrategyJourneyCollapsed()

    private var flow: StrategyFlowDefinition? {
        StrategyFlows.flow(for: strategyId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                    OnboardingStorage.setStrategyJourneyCollapsed(!isExpanded)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: StrategyPlaybookHelpers.strategyIconName(for: strategyId))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .frame(width: 36, height: 36)
                        .background(AppColors.accentMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your strategy")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.accentHighlight)
                            .textCase(.uppercase)
                        Text(
                            StrategyPlaybookHelpers.formatPlaybookTitle(
                                strategyId: strategyId,
                                catalogItem: catalogItem
                            )
                        )
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        Text(catalogItem?.subtitle ?? "Your guided investing playbook")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                        if !isExpanded, let description = catalogItem?.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(AppColors.tertiaryLabel)
                                .lineLimit(2)
                                .lineSpacing(2)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded, let flow {
                StrategySerpentineFlowDiagram(flow: flow)

                Button("Refine in Settings", action: onOpenSettings)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .appPanel(subtle: true)
    }
}
