import SwiftUI
import Charts

struct SecFilingsSectionView: View {
    let filings: SecFilingsResponse?

    var body: some View {
        if let filings, !filings.filings.isEmpty {
            AppGroupedList {
                ForEach(Array(filings.filings.prefix(12).enumerated()), id: \.element.id) { index, filing in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(filing.form)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColors.accentHighlight)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.accentMuted.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            Text("Filed \(filing.filingDate)")
                                .font(.caption2)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                        if !filing.reportDate.isEmpty {
                            Text("Report \(filing.reportDate)")
                                .font(.caption2)
                                .foregroundStyle(AppColors.tertiaryLabel)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if index < min(filings.filings.count, 12) - 1 {
                        AppGroupedDivider()
                    }
                }
            }
        } else {
            AppEmptyMessage(message: "No recent SEC filings found.", systemImage: "folder")
        }
    }
}

struct SecRatiosSectionView: View {
    let ratios: SecRatiosResponse?

    var body: some View {
        if let ratios, !ratios.snapshots.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ratios.snapshots.prefix(8)) { snapshot in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(snapshot.end)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.label)
                            ratioRow("Gross margin", snapshot.grossMargin)
                            ratioRow("Net margin", snapshot.netMargin)
                            ratioRow("ROE", snapshot.roe)
                            ratioRow("Debt/eq", snapshot.debtToEquity)
                            ratioRow("Rev YoY", snapshot.revenueGrowthYoy, asPercent: true)
                        }
                        .padding(10)
                        .frame(width: 140, alignment: .leading)
                        .background(AppColors.secondaryBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        } else {
            AppEmptyMessage(message: "SEC ratio trends are not available.", systemImage: "chart.bar")
        }
    }

    private func ratioRow(_ label: String, _ value: Double?, asPercent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)
            Spacer()
            Text(formatValue(value, asPercent: asPercent))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(AppColors.label)
        }
    }

    private func formatValue(_ value: Double?, asPercent: Bool) -> String {
        guard let value else { return "—" }
        if asPercent { return CurrencyFormatter.percent(value) }
        if abs(value) <= 1 { return CurrencyFormatter.percent(value * 100) }
        return String(format: "%.2f", value)
    }
}

struct SecFinancialTrendSectionView: View {
    let financials: SecFinancialsResponse?

    var body: some View {
        if let financials {
            VStack(alignment: .leading, spacing: 14) {
                trendBlock("Revenue trend", financials.incomeStatement, tag: "Revenues")
                trendBlock("Net income", financials.incomeStatement, tag: "NetIncomeLoss")
                trendBlock("Free cash flow", financials.cashFlow, tag: "NetCashProvidedByUsedInOperatingActivities")
            }
        } else {
            AppEmptyMessage(message: "SEC financial trends are not available.", systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    @ViewBuilder
    private func trendBlock(_ title: String, _ items: [SecFinancialLineItem], tag: String) -> some View {
        if let item = items.first(where: { $0.tag == tag || $0.label.localizedCaseInsensitiveContains(title.split(separator: " ").first.map(String.init) ?? "") }),
           !item.observations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                ForEach(item.observations.prefix(6)) { obs in
                    HStack {
                        Text(obs.end)
                            .font(.caption2)
                            .foregroundStyle(AppColors.secondaryLabel)
                        Spacer()
                        Text(CurrencyFormatter.usd(obs.value, fractionDigits: 0))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            .padding(12)
            .background(AppColors.secondaryBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct GroupedKeyMetricsSection: View {
    let metrics: [FundamentalMetric]

    var body: some View {
        let groups = FundamentalMetricGroups.group(metrics)
        if groups.isEmpty {
            AppEmptyMessage(message: "No fundamental metrics were returned.")
        } else {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .textCase(.uppercase)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(group.metrics) { metric in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(metric.label)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(AppColors.tertiaryLabel)
                                        .lineLimit(2)
                                    Text(metric.value)
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(AppColors.label)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
                                .background(AppColors.secondaryBackground.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct EtfFundsOverviewSection: View {
    let funds: EtfFundsSnapshot?

    var body: some View {
        if let funds {
            AppMetricStrip(items: [
                ("Category", funds.category ?? "—"),
                ("Family", funds.fundFamily ?? "—"),
                ("AUM", funds.totalAssets ?? "—"),
                ("Yield", funds.yield ?? "—"),
                ("YTD", funds.ytdReturn ?? "—"),
            ])
            .appPanel(subtle: true)
        }
    }
}

struct DividendHistoryChartSection: View {
    let dividends: DividendHistoryContext

    var body: some View {
        if !dividends.annualIncome.isEmpty {
            AppScreenSection(title: "Annual dividend income") {
                Chart(dividends.annualIncome) { row in
                    BarMark(
                        x: .value("Year", String(row.year)),
                        y: .value("Income", row.incomeOnShares)
                    )
                    .foregroundStyle(AppColors.accent)
                }
                .frame(height: 160)
                .appPanel(subtle: true)
            }
        }
    }
}

struct WheelBacktestControlsPanel: View {
    @Binding var query: WheelBacktestQuery
    let isLoading: Bool
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Lookback", selection: $query.years) {
                Text("5 years").tag(5)
                Text("10 years").tag(10)
                Text("15 years").tag(15)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("DTE")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                Spacer()
                Picker("DTE", selection: $query.dteDays) {
                    Text("21d").tag(21)
                    Text("30d").tag(30)
                    Text("45d").tag(45)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            Toggle("Maintain one lot", isOn: $query.maintainOneLot)
                .font(.caption)

            Button(action: onRun) {
                HStack {
                    if isLoading { ProgressView().controlSize(.small) }
                    Text(isLoading ? "Running…" : "Run backtest")
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(isLoading)
        }
        .appPanel(subtle: true)
    }
}

struct ChatSessionHistorySheet: View {
    let sessions: [ChatSessionSummary]
    let isLoading: Bool
    let onSelect: (ChatSessionSummary) -> Void
    var onDelete: ((ChatSessionSummary) async -> Void)?

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if sessions.isEmpty {
                Text("No saved chats yet.")
                    .foregroundStyle(AppColors.secondaryLabel)
            } else {
                ForEach(sessions) { session in
                    Button {
                        onSelect(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title ?? "Untitled chat")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.label)
                            Text(session.updatedAt)
                                .font(.caption2)
                                .foregroundStyle(AppColors.tertiaryLabel)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if let onDelete {
                            Button(role: .destructive) {
                                Task { await onDelete(session) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Chat history")
        .navigationBarTitleDisplayMode(.inline)
    }
}
