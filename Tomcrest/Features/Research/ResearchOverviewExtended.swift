import SwiftUI

struct ResearchStockChartSection: View {
    let symbol: String
    @Bindable var viewModel: SymbolOverviewViewModel

    var body: some View {
        AppScreenSection(title: "Price chart", footnote: viewModel.chartPeriod.label) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Period", selection: $viewModel.chartPeriod) {
                    ForEach(StockChartPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.chartPeriod) { _, _ in
                    Task { await viewModel.loadStockChart() }
                }

                if viewModel.isChartLoading, viewModel.stockChart == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let chart = viewModel.stockChart, !chart.data.isEmpty {
                    InteractiveStockPriceChart(points: chart.data)
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

struct BigPictureSection: View {
    @Environment(AccountContext.self) private var account
    let summary: AISummary?
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void

    var body: some View {
        AppScreenSection(
            title: "Big picture",
            footnote: account.hasProFeature(.bigPicture) ? "AI thesis, valuation, strengths & risks" : "Pro feature"
        ) {
            if account.hasProFeature(.bigPicture) {
                if isLoading, summary == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView()
                        Text("Generating AI overview…")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .appPanel(subtle: true)
                } else if let summary {
                    VStack(alignment: .leading, spacing: 10) {
                        BigPictureArticleContent(summary: summary)
                        Button("Refresh Big Picture") {
                            onRefresh()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Get an AI-written overview with thesis, strengths, risks, and what to watch.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                        if let errorMessage {
                            AppInlineBanner(message: errorMessage, tone: .error)
                        }
                        Button("Refresh with full AI analysis", action: onRefresh)
                            .buttonStyle(AppSecondaryButtonStyle())
                    }
                    .appPanel(subtle: true)
                }
            } else {
                AppInlineBanner(
                    message: "Upgrade to Pro for Big Picture — AI thesis, valuation context, and key risks.",
                    tone: .neutral
                )
            }
        }
    }
}

struct BigPictureArticleContent: View {
    let summary: AISummary

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack {
                Text("Sentiment")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                Spacer()
                Text(summary.sentiment)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sentimentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sentimentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            if !summary.keyStrengths.isEmpty || !summary.keyRisks.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    bulletColumn(title: "Key strengths", items: summary.keyStrengths, isRisk: false)
                    bulletColumn(title: "Key risks", items: summary.keyRisks, isRisk: true)
                }
            }

            proseBlock(title: "Investment thesis", text: summary.investmentThesis)
            proseBlock(title: "Valuation context", text: summary.valuationContext)
            proseBlock(title: "Overview", text: summary.long.isEmpty ? summary.short : summary.long)

            if !summary.whatToWatch.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What to watch")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)
                    ForEach(summary.whatToWatch, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                            .foregroundStyle(AppColors.label)
                    }
                }
            }
        }
        .appPanel(subtle: true)
    }

    private var sentimentColor: Color {
        switch summary.sentiment.lowercased() {
        case "bullish": AppColors.success
        case "bearish": AppColors.danger
        default: AppColors.secondaryLabel
        }
    }

    @ViewBuilder
    private func bulletColumn(title: String, items: [String], isRisk: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            ForEach(items.prefix(4), id: \.self) { item in
                Text("• \(item)")
                    .font(.caption)
                    .foregroundStyle(isRisk ? AppColors.warning : AppColors.label)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func proseBlock(title: String, text: String) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                Text(trimmed)
                    .font(.caption)
                    .foregroundStyle(AppColors.label)
                    .lineSpacing(3)
            }
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
