import SwiftUI

struct StrategySymbolPlaybookStrip: View {
    @Environment(AccountContext.self) private var account
    let symbol: String
    let strategyId: String?
    let catalogItem: StrategyCatalogItem?
    let recommendations: StrategyRecommendations?
    let profileSymbols: [String]
    var onRunAction: (StrategyNextAction) -> Void
    var onOpenBacktest: () -> Void

    private var isOnPlaybook: Bool {
        guard strategyId != nil else { return false }
        return profileSymbols.contains(symbol.uppercased())
    }

    private var symbolStatus: StrategySymbolStatus? {
        recommendations?.symbolStatuses?.first { $0.symbol.uppercased() == symbol.uppercased() }
    }

    var body: some View {
        if isOnPlaybook, let strategyId, let status = symbolStatus {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Strategy playbook", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                    Spacer()
                    Text(StrategyPlaybookHelpers.formatPlaybookTitle(strategyId: strategyId, catalogItem: catalogItem))
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                }

                Text(status.statusLabel)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)

                if StrategyPlaybookHelpers.isWheelLikeStrategy(strategyId), status.wheelPhase != nil {
                    StrategyWheelPhaseStepper(strategyId: strategyId, phase: status.wheelPhase)
                }

                if let nextAction = status.nextAction {
                    Text(nextAction.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)

                    HStack(spacing: 8) {
                        if StrategyPlaybookHelpers.playbookActionAskable(nextAction) {
                            Button("Ask AI") { onRunAction(nextAction) }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.accentHighlight)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppColors.accentMuted.opacity(0.5))
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                        }

                        if strategyId == "wheel", account.hasProFeature(.wheelBacktest) {
                            Button("Backtest", action: onOpenBacktest)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.secondaryLabel)
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .appPanel(subtle: true)
        }
    }
}
