import SwiftUI

struct MomentumBreakoutAlertsView: View {
    @Bindable var viewModel: MomentumBreakoutAlertsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            if viewModel.featureFlags.alertsEnabled {
                MomentumBreakoutInvestorBrief(
                    scan: viewModel.scanSummary,
                    paperSummary: viewModel.paperSummary,
                    loading: viewModel.scanLoading,
                    errorMessage: viewModel.scanErrorMessage,
                    trackedSymbols: viewModel.trackedSymbols,
                    onTrackPlan: { symbol in
                        await viewModel.trackPlan(symbol: symbol)
                    }
                )
                MomentumBreakoutStockCheck(viewModel: viewModel)
                watchlistHeader
                    .id(MomentumBreakoutInvestorCopy.watchlistSectionId)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                viewModel.watchlistHighlight
                                    ? AppColors.accentHighlight.opacity(0.55)
                                    : Color.clear,
                                lineWidth: 2
                            )
                    }
                tabPicker
            }
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
            if viewModel.featureFlags.alertsEnabled,
               viewModel.featureFlags.paperAnalyticsEnabled {
                paperPerformanceSection
                    .task {
                        await viewModel.loadPaperPerformanceIfNeeded()
                    }
            }
            footerNote
        }
        .onChange(of: viewModel.selectedTab, initial: true) { _, tab in
            guard tab == .history else { return }
            Task { await viewModel.loadHistoryIfNeeded() }
        }
    }

    private var watchlistHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your watchlist")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
            if !viewModel.disclaimer.isEmpty {
                Text(viewModel.disclaimer)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                if let updated = viewModel.lastUpdated {
                    Text(
                        "Watchlist prices: \(updated.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.secondaryLabel)
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
            Text(viewModel.paperMeta?.label ?? "Practice tracking (optional)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
            if let disclaimer = viewModel.paperMeta?.disclaimer, !disclaimer.isEmpty {
                Text(disclaimer)
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Hypothetical results only — not the same as your live watchlist above.")
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)

            if let paperPerformanceError = viewModel.paperPerformanceError {
                Text(paperPerformanceError)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            } else if let summary = viewModel.paperSummary {
                HStack(spacing: 12) {
                    paperStat("Wins", MomentumBreakoutAlertPresentation.formatPct(summary.winRate))
                    paperStat("Profit score", MomentumBreakoutAlertPresentation.formatRatio(summary.profitFactor))
                    paperStat("Avg return", MomentumBreakoutAlertPresentation.formatPct(summary.expectancy))
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
        if !viewModel.featureFlags.alertsEnabled {
            VStack(alignment: .leading, spacing: 8) {
                Text("Temporarily unavailable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(
                    "Stock breakout watchlist is disabled during a controlled rollout."
                )
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appPanel(subtle: true)
        } else if viewModel.isLoading, viewModel.displayedAlerts.isEmpty {
            ProgressView("Loading trade plan alerts…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else if viewModel.displayedAlerts.isEmpty, viewModel.errorMessage == nil {
            emptyState
        } else {
            VStack(spacing: Layout.sectionSpacing) {
                ForEach(viewModel.displayedAlerts) { alert in
                    alertRow(alert)
                }
            }
        }
    }

    @ViewBuilder
    private func alertRow(_ alert: MomentumBreakoutAlertDto) -> some View {
        let card = MomentumBreakoutAlertCard(alert: alert)
        if viewModel.selectedTab == .active,
           let alertId = alert.alertId,
           MomentumBreakoutAlertPresentation.isCancellable(alert.lifecycleStatus) {
            card
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.cancelAlert(alertId: alertId) }
                    } label: {
                        if viewModel.cancellingAlertId == alertId {
                            Label("Cancelling…", systemImage: "hourglass")
                        } else {
                            Label("Stop tracking", systemImage: "xmark.circle")
                        }
                    }
                    .disabled(viewModel.cancellingAlertId == alertId)
                }
        } else {
            card
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.selectedTab == .active {
            MomentumBreakoutStructuredEmpty(
                title: "No Active Alerts",
                happened: "You do not currently have any breakout plans being monitored.",
                doing: "We continue scanning the market during trading hours.",
                expectNext: "When a qualified opportunity is saved, it will appear here automatically."
            )
        } else {
            MomentumBreakoutStructuredEmpty(
                title: "No Completed Alerts",
                happened: "None of your tracked plans have completed yet.",
                doing: "We keep monitoring active plans for entry, stop, and target prices.",
                expectNext: "Completed plans appear here when they hit a target, stop, or expiry date."
            )
        }
    }

    private var footerNote: some View {
        Text("Active alerts refresh every 60 seconds. Refresh pulls the latest prices immediately.")
            .font(.caption2)
            .foregroundStyle(AppColors.tertiaryLabel)
    }
}

/// Hosts scroll bindings for `@Observable` view model (`$` requires `@Bindable`, not optional `if let`).
private struct MomentumBreakoutAlertsScrollHost: View {
    @Bindable var viewModel: MomentumBreakoutAlertsViewModel

    var body: some View {
        AppScrollScreen(
            refresh: { await viewModel.manualRefresh() },
            scrollToToken: $viewModel.scrollToToken,
            scrollAnchor: viewModel.scrollAnchorId
        ) {
            MomentumBreakoutAlertsView(viewModel: viewModel)
        }
    }
}

struct MomentumBreakoutAlertsScreen: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel: MomentumBreakoutAlertsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                MomentumBreakoutAlertsScrollHost(viewModel: viewModel)
            } else {
                AppScrollScreen {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            }
        }
        .appDetailNavigation()
        .navigationTitle("Breakout watchlist")
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
