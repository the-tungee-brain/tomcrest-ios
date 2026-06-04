import SwiftUI

struct MomentumBreakoutAlertsView: View {
    @Bindable var viewModel: MomentumBreakoutAlertsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            header
            paperPerformanceSection
            tabPicker
            if let error = viewModel.errorMessage, viewModel.displayedAlerts.isEmpty {
                AppInlineBanner(message: error, tone: .error)
            }
            if !viewModel.refreshWarnings.isEmpty {
                AppInlineBanner(
                    message: viewModel.refreshWarnings.joined(separator: " "),
                    tone: .neutral
                )
            }
            content
            footerNote
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Momentum Breakout trade plans")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.label)
            if !viewModel.disclaimer.isEmpty {
                Text(viewModel.disclaimer)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                if let updated = viewModel.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
                Spacer()
                Button {
                    Task { await viewModel.manualRefresh() }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isRefreshing)
            }
        }
    }

    private var paperPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.paperMeta?.label ?? "Live paper-trading performance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
            if let disclaimer = viewModel.paperMeta?.disclaimer, !disclaimer.isEmpty {
                Text(disclaimer)
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Historical backtest stats on alert cards are separate research simulations.")
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)

            if let paperPerformanceError = viewModel.paperPerformanceError {
                Text(paperPerformanceError)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            } else if let summary = viewModel.paperSummary {
                HStack(spacing: 12) {
                    paperStat("Win rate", MomentumBreakoutAlertPresentation.formatPct(summary.winRate))
                    paperStat("Profit factor", MomentumBreakoutAlertPresentation.formatRatio(summary.profitFactor))
                    paperStat("Expectancy", MomentumBreakoutAlertPresentation.formatPct(summary.expectancy))
                }
                if viewModel.recentPaperOutcomes.isEmpty {
                    Text("No completed paper trades yet.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                } else {
                    Text("Recent outcomes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                    ForEach(viewModel.recentPaperOutcomes.prefix(5)) { trade in
                        HStack {
                            Text(trade.symbol)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(trade.status.replacingOccurrences(of: "_", with: " "))
                                .font(.caption2)
                                .foregroundStyle(AppColors.tertiaryLabel)
                            Text(MomentumBreakoutAlertPresentation.formatPct(trade.outcomeReturnPct))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    (trade.outcomeReturnPct ?? 0) >= 0
                                        ? AppColors.success
                                        : AppColors.error
                                )
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }

    private func paperStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.label)
        }
    }

    private var tabPicker: some View {
        Picker("Alerts", selection: $viewModel.selectedTab) {
            ForEach(MomentumBreakoutAlertsTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.displayedAlerts.isEmpty {
            ProgressView("Loading trade plan alerts…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else if viewModel.displayedAlerts.isEmpty, viewModel.errorMessage == nil {
            emptyState
        } else {
            VStack(spacing: Layout.sectionSpacing) {
                ForEach(viewModel.displayedAlerts) { alert in
                    MomentumBreakoutAlertCard(alert: alert)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.selectedTab == .active ? "No active trade plan alerts" : "No alert history yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
            Text(
                viewModel.selectedTab == .active
                    ? "Saved Momentum Breakout trade plans appear here while entry, stop, and target levels are monitored."
                    : "Completed, stopped, or expired trade plans appear in history."
            )
            .font(.caption)
            .foregroundStyle(AppColors.secondaryLabel)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }

    private var footerNote: some View {
        Text("Active alerts refresh every 60 seconds. Refresh pulls the latest prices immediately.")
            .font(.caption2)
            .foregroundStyle(AppColors.tertiaryLabel)
    }
}

struct MomentumBreakoutAlertsScreen: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel: MomentumBreakoutAlertsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AppScrollScreen(refresh: { await viewModel.manualRefresh() }) {
                    MomentumBreakoutAlertsView(viewModel: viewModel)
                }
            } else {
                AppScrollScreen {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            }
        }
        .appDetailNavigation()
        .navigationTitle("Trade plan alerts")
        .task {
            if viewModel == nil {
                let model = MomentumBreakoutAlertsViewModel(auth: auth)
                viewModel = model
                await model.loadAll()
                model.start()
            }
        }
        .onDisappear {
            viewModel?.stop()
        }
    }
}
