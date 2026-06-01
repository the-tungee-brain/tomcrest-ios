import SwiftUI

struct WheelBacktestExtendedPanel: View {
    let result: WheelBacktestResult
    let query: WheelBacktestQuery

    @State private var expandedCycles: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            AppScreenSection(title: "Wheel backtest", footnote: "\(result.lookbackYears)-year lookback") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    kpi("Total return", CurrencyFormatter.percent(result.totalReturnPct))
                    kpi("CAGR", CurrencyFormatter.percent(result.cagrPct ?? 0))
                    kpi("Buy & hold", CurrencyFormatter.percent(result.buyAndHoldReturnPct))
                    kpi("Premium", CurrencyFormatter.usd(result.totalPremiumCollectedUsd, fractionDigits: 0))
                    kpi("Put assignments", "\(result.putAssignments)")
                    kpi("Wheel cycles", "\(result.completedWheelCycles)")
                }
            }

            PdfShareButton(
                title: "Download PDF",
                url: PdfExportSupport.writeWheelBacktestPdf(result, query: query)
            )

            if !result.equityCurve.isEmpty {
                AppScreenSection(title: "Equity curve", footnote: "Drag to scrub · gray = buy & hold") {
                    InteractiveEquityCurveChart(points: result.equityCurve)
                        .appPanel(subtle: true)
                }
            }

            if let annual = result.annualSummary, !annual.isEmpty {
                AppScreenSection(title: "Year-by-year") {
                    VStack(spacing: 8) {
                        ForEach(annual) { row in
                            HStack {
                                Text(String(row.year))
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text(CurrencyFormatter.percent(row.returnPct ?? 0))
                                    .font(.caption.monospacedDigit())
                                Text(CurrencyFormatter.usd(row.plUsd ?? 0, fractionDigits: 0))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                    }
                    .appPanel(subtle: true)
                }
            }

            if let cycles = result.wheelCycles, !cycles.isEmpty {
                AppScreenSection(title: "Assigned cycles", footnote: "\(cycles.count) cycles") {
                    VStack(spacing: 8) {
                        ForEach(cycles) { cycle in
                            HStack {
                                Text("Cycle \(cycle.cycle)")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text("Put \(cycle.putStrike.map { CurrencyFormatter.usd($0) } ?? "—")")
                                    .font(.caption2.monospacedDigit())
                                Text("Call \(cycle.callStrike.map { CurrencyFormatter.usd($0) } ?? "—")")
                                    .font(.caption2.monospacedDigit())
                            }
                        }
                    }
                    .appPanel(subtle: true)
                }
            }

            if !result.trades.isEmpty {
                AppScreenSection(title: "Trade log", footnote: "\(result.trades.count) trades") {
                    VStack(spacing: 10) {
                        ForEach(WheelBacktestGrouping.tradesByCycle(result.trades), id: \.cycle) { group in
                            if group.cycle > 0 {
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedCycles.contains(group.cycle) },
                                        set: { expanded in
                                            if expanded { expandedCycles.insert(group.cycle) }
                                            else { expandedCycles.remove(group.cycle) }
                                        }
                                    )
                                ) {
                                    ForEach(group.trades) { trade in
                                        tradeRow(trade)
                                    }
                                } label: {
                                    Text("Cycle \(group.cycle) · \(group.trades.count) trades")
                                        .font(.caption.weight(.semibold))
                                }
                            } else {
                                ForEach(group.trades) { trade in
                                    tradeRow(trade)
                                }
                            }
                        }
                    }
                }
            }

            if let assumptions = result.assumptions, !assumptions.isEmpty {
                AppScreenSection(title: "Assumptions") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(assumptions, id: \.self) { item in
                            Text("• \(item)")
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                    }
                    .appPanel(subtle: true)
                }
            }
        }
    }

    private func tradeRow(_ trade: WheelBacktestTrade) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(DateFormatters.display(from: trade.date)) · \(trade.action)")
                .font(.caption.weight(.semibold))
            if let label = trade.label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func kpi(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct StreetAnalysisOverviewPreview: View {
    let street: StreetAnalysisSnapshot?

    var body: some View {
        if StreetAnalysisFormatters.hasStreetAnalysis(street), let street {
            AppScreenSection(title: "Wall Street analysis", footnote: "Analyst ratings & targets") {
                VStack(alignment: .leading, spacing: 10) {
                    if let consensus = street.consensusLabel {
                        HStack {
                            Text("Consensus")
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                            Spacer()
                            Text(consensus)
                                .font(.caption.weight(.semibold))
                        }
                    }
                    if let targets = street.priceTargets, let upside = targets.upsideToMeanPct {
                        HStack {
                            Text("Upside to mean")
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                            Spacer()
                            Text(StreetAnalysisFormatters.formatUpside(upside))
                                .font(.caption.weight(.semibold).monospacedDigit())
                        }
                    }
                    if let headline = street.estimateRevisionHeadline ?? street.growthContextHeadline,
                       !headline.isEmpty {
                        Text(headline)
                            .font(.caption2)
                            .foregroundStyle(AppColors.label)
                            .lineSpacing(2)
                    }
                    Text("See Fundamentals tab for full analyst coverage.")
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
                .appPanel(subtle: true)
            }
        }
    }
}

struct EtfHoldingsOverviewPreview: View {
    let holdings: EtfHoldingsContext?

    var body: some View {
        if let holdings, !holdings.holdings.isEmpty {
            AppScreenSection(title: "Top holdings", footnote: "\(holdings.totalHoldings) total") {
                VStack(spacing: 8) {
                    ForEach(holdings.holdings.prefix(5)) { item in
                        HStack {
                            Text(item.ticker ?? item.name)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(CurrencyFormatter.compactPercent(item.weightPct))
                                .font(.caption.monospacedDigit())
                        }
                    }
                    Text("See Composition tab for sector breakdown and full list.")
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .appPanel(subtle: true)
            }
        }
    }
}

private extension CurrencyFormatter {
    static func compactPercent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }
}
