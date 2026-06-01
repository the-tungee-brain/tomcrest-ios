import SwiftUI

enum BacktestExploreSection: String, Hashable, CaseIterable, Identifiable {
    case dividend
    case wheel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dividend: "Dividend backtest"
        case .wheel: "Wheel backtest"
        }
    }

    var subtitle: String {
        switch self {
        case .dividend:
            "Replay actual dividend payments with DRIP and contributions"
        case .wheel:
            "Simulate put/call wheel cycles, premium, and assignment history"
        }
    }

    var icon: String {
        switch self {
        case .dividend: "dollarsign.circle.fill"
        case .wheel: "chart.xyaxis.line"
        }
    }

    var iconTint: Color {
        switch self {
        case .dividend: AppColors.accentHighlight
        case .wheel: Color(hex: 0xa78bfa)
        }
    }
}

struct SymbolBacktestTab: View {
    @Environment(AccountContext.self) private var account
    @Binding var exploreSection: BacktestExploreSection?
    @Bindable var viewModel: SymbolDepthViewModel
    let primaryStrategy: String?
    var marketSharePrice: Double?

    var body: some View {
        ResearchDepthTabShell(tab: .more, viewModel: viewModel) {
            if let exploreSection {
                backtestDetail(exploreSection)
            } else {
                backtestHub
            }
        }
    }

    private var backtestHub: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("What is a backtest?")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .textCase(.uppercase)

                Text(
                    "A backtest replays history with your assumptions — share count, reinvestment, contributions, and time window — so you can see what would have happened before changing strategy."
                )
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.label)
                .lineSpacing(3)

                Text(
                    "Results are modeled from historical data and your inputs. They help compare scenarios; they are not a guarantee of future performance."
                )
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)
            }
            .padding(16)
            .appPanel(subtle: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Explore")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(BacktestExploreSection.allCases.enumerated()), id: \.element.id) { index, section in
                        Button {
                            exploreSection = section
                        } label: {
                            PortfolioQuickLinkRow(
                                icon: section.icon,
                                iconTint: section.iconTint,
                                title: section.title,
                                subtitle: section.subtitle
                            )
                        }
                        .buttonStyle(.plain)

                        if index < BacktestExploreSection.allCases.count - 1 {
                            Divider().overlay(AppColors.separator).padding(.leading, 58)
                        }
                    }
                }
                .background(AppColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.panelBorder, lineWidth: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func backtestDetail(_ section: BacktestExploreSection) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            Button {
                exploreSection = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text("Explore backtests")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppColors.accentHighlight)
            }
            .buttonStyle(.plain)

            switch section {
            case .dividend:
                if let context = viewModel.dividends {
                    DividendBacktestSection(
                        context: context,
                        marketSharePrice: marketSharePrice,
                        viewModel: viewModel
                    )
                } else if viewModel.loadingTab == .more {
                    AppLoadingState(message: "Loading dividend history…")
                } else {
                    AppEmptyMessage(message: "Open the Dividends tab first, or pull to refresh this tab.")
                }
            case .wheel:
                WheelBacktestSection(
                    viewModel: viewModel,
                    primaryStrategy: primaryStrategy
                )
            }
        }
    }
}

struct WheelBacktestSection: View {
    @Environment(AccountContext.self) private var account
    @Bindable var viewModel: SymbolDepthViewModel
    let primaryStrategy: String?

    private var isWheelStrategy: Bool {
        primaryStrategy == "wheel"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wheel backtest")
                    .font(.headline)
                    .foregroundStyle(AppColors.label)
                Text(
                    "Simulates selling cash-secured puts, taking assignment, and selling covered calls over a historical window. Adjust delta, DTE, and lot maintenance, then compare total return to buy-and-hold."
                )
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)
            }

            if !isWheelStrategy {
                AppInlineBanner(
                    message: "Best suited for wheel strategy symbols. Set your primary strategy to Wheel in Settings for playbook alignment.",
                    tone: .neutral
                )
            }

            if account.hasProFeature(.wheelBacktest) {
                WheelBacktestControlsPanel(
                    query: $viewModel.wheelBacktestQuery,
                    isLoading: viewModel.wheelBacktestLoading,
                    onRun: {
                        Task { await viewModel.runWheelBacktest() }
                    }
                )

                if let error = viewModel.tabErrors[.more] {
                    AppInlineBanner(message: error, tone: .error)
                }

                if let result = viewModel.wheelBacktest {
                    WheelBacktestExtendedPanel(result: result, query: viewModel.wheelBacktestQuery)
                } else if !viewModel.wheelBacktestLoading {
                    Text("Run a backtest to see results.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                AppInlineBanner(
                    message: "Upgrade to Pro for wheel backtest with trade log and equity curve.",
                    tone: .neutral
                )
            }
        }
    }
}
