import Charts
import SwiftUI

enum ChartDateParser {
    static func date(from raw: String) -> Date {
        ISO8601DateFormatter().date(from: raw)
            ?? ISO8601DateFormatter().date(from: raw + "T00:00:00Z")
            ?? Date()
    }
}

private enum ChartVolumeFormatter {
    static func compact(_ value: Int) -> String {
        let amount = Double(value)
        if amount >= 1_000_000_000 {
            return String(format: "%.1fB", amount / 1_000_000_000)
        }
        if amount >= 1_000_000 {
            return String(format: "%.1fM", amount / 1_000_000)
        }
        if amount >= 1_000 {
            return String(format: "%.1fK", amount / 1_000)
        }
        return String(value)
    }
}

private var tomcrestLinePlotConfig: RHLinePlotConfig {
    RHLinePlotConfig.default.custom { config in
        config.plotLineWidth = 2
        config.glowingIndicatorWidth = 9
        config.glowingIndicatorBackgroundScaleEffect = 2.8
        config.glowingIndicatorGlowAnimationDuration = 0.75
        config.glowingIndicatorDelayBetweenGlow = 0.4
        config.valueStickColor = AppColors.tertiaryLabel
        config.valueStickTopPadding = 8
        config.valueStickBottomPadding = 8
        config.minimumPressDurationToActivateInteraction = 0.05
    }
}

// MARK: - Stock price chart (Robinhood-style via RHLinePlot)

struct InteractiveStockPriceChart: View {
    let prepared: IntradayChartTimeline.PreparedChart
    var previousClose: Double?
    var showsIntradayAxis = false

    @State private var selectedIndex: Int?

    private var chartPoints: [StockChartPoint] {
        prepared.points
    }

    private var closeValues: [CGFloat] {
        prepared.values
    }

    private var occupyingRelativeWidth: CGFloat {
        prepared.occupyingRelativeWidth
    }

    private var displayIndex: Int {
        if let selectedIndex, chartPoints.indices.contains(selectedIndex) {
            return selectedIndex
        }
        return max(chartPoints.count - 1, 0)
    }

    private var displayPoint: StockChartPoint? {
        guard chartPoints.indices.contains(displayIndex) else { return nil }
        return chartPoints[displayIndex]
    }

    private var lineColor: Color {
        let baseline = previousClose ?? chartPoints.first?.close
        guard let baseline, let last = chartPoints.last?.close else {
            return AppColors.accent
        }
        return last >= baseline ? AppColors.success : AppColors.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let point = displayPoint {
                stockReadout(point, scrubbing: selectedIndex != nil)
            }

            if chartPoints.count < 2 {
                AppEmptyMessage(
                    message: "Not enough data to draw this chart.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .frame(height: 180)
            } else {
                StockPriceLinePlot(
                    values: closeValues,
                    occupyingRelativeWidth: occupyingRelativeWidth,
                    lineColor: lineColor,
                    selectedIndex: $selectedIndex
                )

                if showsIntradayAxis {
                    intradaySessionAxis
                }
            }
        }
        .onChange(of: prepared.points.count) { _, _ in
            selectedIndex = nil
        }
    }
}

/// Isolated plot layer so scrubbing only re-renders the readout + stick, not the whole section.
private struct StockPriceLinePlot: View {
    let values: [CGFloat]
    let occupyingRelativeWidth: CGFloat
    let lineColor: Color
    @Binding var selectedIndex: Int?

    var body: some View {
        RHInteractiveLinePlot(
            values: values,
            occupyingRelativeWidth: occupyingRelativeWidth,
            showGlowingIndicator: true,
            didSelectValueAtIndex: { index in
                selectedIndex = index
            },
            valueStickLabel: { _ in
                Text(" ")
                    .font(.caption2)
            }
        )
        .frame(height: 200)
        .foregroundColor(lineColor)
        .environment(\.rhLinePlotConfig, tomcrestLinePlotConfig)
    }
}

extension InteractiveStockPriceChart {

    private var intradaySessionAxis: some View {
        HStack {
            Text("4 AM")
            Spacer()
            Text("8 AM")
            Spacer()
            Text("12 PM")
            Spacer()
            Text("4 PM")
            Spacer()
            Text("8 PM")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(AppColors.tertiaryLabel)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func stockReadout(_ point: StockChartPoint, scrubbing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateFormatters.display(from: point.date))
                .font(.caption2.weight(.medium))
                .foregroundStyle(scrubbing ? AppColors.accentHighlight : AppColors.secondaryLabel)

            HStack(spacing: 10) {
                readoutMetric("O", CurrencyFormatter.usd(point.open))
                readoutMetric("H", CurrencyFormatter.usd(point.high))
                readoutMetric("L", CurrencyFormatter.usd(point.low))
                readoutMetric("C", CurrencyFormatter.usd(point.close))
                readoutMetric("Vol", ChartVolumeFormatter.compact(point.volume))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceElevated.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(nil, value: selectedIndex)
    }

    private func readoutMetric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColors.label)
        }
    }
}

// MARK: - Annual bar chart

struct InteractiveAnnualBarChart: View {
    let rows: [AnnualDividendIncome]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let row = rows.last {
                HStack {
                    Text(String(row.year))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Spacer()
                    Text(CurrencyFormatter.usd(row.incomeOnShares, fractionDigits: 0))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppColors.label)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppColors.surfaceElevated.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Chart(rows) { row in
                BarMark(
                    x: .value("Year", String(row.year)),
                    y: .value("Income", row.incomeOnShares)
                )
                .foregroundStyle(AppColors.accent)
            }
            .frame(height: 160)
        }
    }
}

// MARK: - Dividend backtest year chart

struct InteractiveDividendBacktestYearChart: View {
    let rows: [DividendBacktestYearRow]

    @State private var selectedYearLabel: String?

    private var displayRow: DividendBacktestYearRow? {
        if let selectedYearLabel,
           let year = Int(selectedYearLabel),
           let row = rows.first(where: { $0.year == year }) {
            return row
        }
        return rows.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let row = displayRow {
                backtestYearReadout(row, scrubbing: selectedYearLabel != nil)
            }

            if rows.isEmpty {
                AppEmptyMessage(
                    message: "No yearly breakdown available.",
                    systemImage: "chart.bar"
                )
                .frame(height: 160)
            } else {
                Chart(rows) { row in
                    BarMark(
                        x: .value("Year", String(row.year)),
                        y: .value("Income", row.dividendIncome)
                    )
                    .foregroundStyle(
                        selectedYearLabel == String(row.year)
                            ? AppColors.accentHighlight
                            : AppColors.accent
                    )
                }
                .chartXSelection(value: $selectedYearLabel)
                .frame(height: 180)
            }
        }
    }

    @ViewBuilder
    private func backtestYearReadout(_ row: DividendBacktestYearRow, scrubbing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(row.year))
                .font(.caption2.weight(.medium))
                .foregroundStyle(scrubbing ? AppColors.accentHighlight : AppColors.secondaryLabel)

            HStack(spacing: 10) {
                readoutMetric("Income", CurrencyFormatter.usd(row.dividendIncome, fractionDigits: 0))
                readoutMetric("DPS", String(format: "$%.4f", row.dps))
                readoutMetric("Shares", String(format: "%.2f", row.shares))
                readoutMetric("Yield", String(format: "%.2f%%", row.dividendYieldPct))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceElevated.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: scrubbing)
    }

    private func readoutMetric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColors.label)
        }
    }
}

// MARK: - Equity curve chart

private struct EquityCurveChartModel {
    let equityValues: [CGFloat]
    let buyHoldValues: [CGFloat]?
    let lineColor: Color

    init(points: [WheelBacktestEquityPoint]) {
        equityValues = points.map { CGFloat($0.equityUsd) }
        if points.allSatisfy({ ($0.buyAndHoldEquityUsd ?? 0) > 0 }) {
            buyHoldValues = points.map { CGFloat($0.buyAndHoldEquityUsd ?? 0) }
        } else {
            buyHoldValues = nil
        }

        if let first = points.first?.equityUsd, let last = points.last?.equityUsd {
            lineColor = last >= first ? AppColors.success : AppColors.error
        } else {
            lineColor = AppColors.accent
        }
    }
}

private struct EquityCurveBuyHoldLine: View, Equatable {
    let values: [CGFloat]

    var body: some View {
        RHLinePlot(
            values: values,
            showGlowingIndicator: false,
            customLatestValueIndicator: {
                Color.clear.frame(width: 0, height: 0)
            }
        )
        .foregroundColor(AppColors.secondaryLabel.opacity(0.4))
        .environment(\.rhLinePlotConfig, tomcrestLinePlotConfig)
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

private struct EquityCurveInteractiveLine: View {
    let values: [CGFloat]
    let lineColor: Color
    @Binding var selectedIndex: Int?

    var body: some View {
        RHInteractiveLinePlot(
            values: values,
            showGlowingIndicator: true,
            didSelectValueAtIndex: { index in
                guard selectedIndex != index else { return }
                selectedIndex = index
            },
            valueStickLabel: { _ in
                Text(" ")
                    .font(.caption2)
            }
        )
        .foregroundColor(lineColor)
        .environment(\.rhLinePlotConfig, tomcrestLinePlotConfig)
    }
}

struct InteractiveEquityCurveChart: View {
    let points: [WheelBacktestEquityPoint]
    private let model: EquityCurveChartModel

    @State private var selectedIndex: Int?

    init(points: [WheelBacktestEquityPoint]) {
        self.points = points
        self.model = EquityCurveChartModel(points: points)
    }

    private var displayIndex: Int {
        if let selectedIndex, points.indices.contains(selectedIndex) {
            return selectedIndex
        }
        return max(points.count - 1, 0)
    }

    private var displayPoint: WheelBacktestEquityPoint? {
        guard points.indices.contains(displayIndex) else { return nil }
        return points[displayIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let point = displayPoint {
                equityReadout(point, scrubbing: selectedIndex != nil)
                    .animation(nil, value: selectedIndex)
            }

            if points.count < 2 {
                AppEmptyMessage(
                    message: "Not enough data to draw this chart.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .frame(height: 180)
            } else {
                ZStack {
                    if let buyHoldValues = model.buyHoldValues {
                        EquityCurveBuyHoldLine(values: buyHoldValues)
                            .equatable()
                    }

                    EquityCurveInteractiveLine(
                        values: model.equityValues,
                        lineColor: model.lineColor,
                        selectedIndex: $selectedIndex
                    )
                }
                .frame(height: 200)
            }
        }
    }

    @ViewBuilder
    private func equityReadout(_ point: WheelBacktestEquityPoint, scrubbing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateFormatters.display(ChartDateParser.date(from: point.date)))
                .font(.caption2.weight(.medium))
                .foregroundStyle(scrubbing ? AppColors.accentHighlight : AppColors.secondaryLabel)

            HStack(spacing: 10) {
                readoutMetric("Strategy", CurrencyFormatter.usd(point.equityUsd, fractionDigits: 0))
                if let buyHold = point.buyAndHoldEquityUsd {
                    readoutMetric("Buy & hold", CurrencyFormatter.usd(buyHold, fractionDigits: 0))
                }
                if let cash = point.cashUsd {
                    readoutMetric("Cash", CurrencyFormatter.usd(cash, fractionDigits: 0))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceElevated.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func readoutMetric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColors.label)
        }
    }
}
