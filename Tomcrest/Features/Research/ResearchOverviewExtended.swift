import SwiftUI

struct ResearchStockChartSection: View {
    let symbol: String
    @Bindable var viewModel: SymbolOverviewViewModel

    var body: some View {
        AppScreenSection(
            title: "Price chart",
            footnote: viewModel.chartPeriod == .oneDay
                ? "Today · 4:00 AM – 8:00 PM PT"
                : viewModel.chartPeriod.label
        ) {
            VStack(alignment: .leading, spacing: 10) {
                AppHorizontalScrollRow {
                    HStack(spacing: 8) {
                        ForEach(StockChartPeriod.allCases) { period in
                            AppChip(
                                title: period.label,
                                isSelected: viewModel.chartPeriod == period
                            ) {
                                viewModel.chartPeriod = period
                            }
                        }
                    }
                }
                .onChange(of: viewModel.chartPeriod) { _, _ in
                    Task { await viewModel.loadStockChart() }
                }

                if viewModel.isChartLoading, viewModel.stockChart == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let prepared = viewModel.preparedStockChart, !prepared.points.isEmpty {
                    InteractiveStockPriceChart(
                        prepared: prepared,
                        previousClose: viewModel.stockChart?.previousClose,
                        showsIntradayAxis: viewModel.chartPeriod.isRobinhoodIntradaySession
                    )
                } else if let error = viewModel.chartError {
                    AppInlineBanner(message: error, tone: .error)
                } else {
                    AppEmptyMessage(message: "Chart data is not available.", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            .appPanel(subtle: true)
        }
        .task {
            await viewModel.loadStockChartIfNeeded()
        }
    }
}

struct SymbolIntelligenceOverviewPanel: View {
    let signals: [IntelligenceSignal]
    var onAskAbout: ((String) -> Void)?

    private var sortedSignals: [IntelligenceSignal] {
        IntelligenceHelpers.sortSignalsBySeverity(signals)
    }

    var body: some View {
        if !sortedSignals.isEmpty {
            AppScreenSection(title: "Intelligence", footnote: "\(sortedSignals.count) signals") {
                VStack(spacing: 10) {
                    ForEach(sortedSignals.prefix(6)) { signal in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(signal.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.label)
                                Spacer(minLength: 8)
                                Text(signal.severity.rawValue.capitalized)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(severityColor(signal.severity))
                            }
                            Text(signal.message)
                                .font(.caption2)
                                .foregroundStyle(AppColors.secondaryLabel)
                                .lineSpacing(2)
                            if let onAskAbout {
                                Button("Ask about this") {
                                    onAskAbout("Explain this signal for my research: \(signal.message)")
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.accentHighlight)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surfaceElevated.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func severityColor(_ severity: SignalSeverity) -> Color {
        switch severity {
        case .critical, .warning: AppColors.warning
        case .watch: AppColors.secondaryLabel
        case .info: AppColors.accentHighlight
        }
    }
}
