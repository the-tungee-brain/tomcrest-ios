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
        config.glowingIndicatorWidth = 10
        config.valueStickColor = AppColors.accentHighlight
        config.valueStickTopPadding = 8
        config.valueStickBottomPadding = 8
        config.minimumPressDurationToActivateInteraction = 0.05
    }
}

// MARK: - Stock price chart (Robinhood-style via RHLinePlot)

struct InteractiveStockPriceChart: View {
    let points: [StockChartPoint]

    @State private var selectedIndex: Int?

    private var closeValues: [CGFloat] {
        points.map { CGFloat($0.close) }
    }

    private var displayIndex: Int {
        if let selectedIndex, points.indices.contains(selectedIndex) {
            return selectedIndex
        }
        return max(points.count - 1, 0)
    }

    private var displayPoint: StockChartPoint? {
        guard points.indices.contains(displayIndex) else { return nil }
        return points[displayIndex]
    }

    private var lineColor: Color {
        guard let first = points.first?.close, let last = points.last?.close else {
            return AppColors.accent
        }
        return last >= first ? AppColors.success : AppColors.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let point = displayPoint {
                stockReadout(point, scrubbing: selectedIndex != nil)
            }

            if points.count < 2 {
                AppEmptyMessage(
                    message: "Not enough data to draw this chart.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .frame(height: 180)
            } else {
                RHInteractiveLinePlot(
                    values: closeValues,
                    showGlowingIndicator: true,
                    didSelectValueAtIndex: { index in
                        selectedIndex = index
                    },
                    valueStickLabel: { _ in
                        if let point = displayPoint {
                            Text(DateFormatters.display(ChartDateParser.date(from: point.date)))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppColors.secondaryLabel)
                        } else {
                            Text("")
                        }
                    }
                )
                .frame(height: 200)
                .foregroundColor(lineColor)
                .environment(\.rhLinePlotConfig, tomcrestLinePlotConfig)
            }
        }
    }

    @ViewBuilder
    private func stockReadout(_ point: StockChartPoint, scrubbing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateFormatters.display(ChartDateParser.date(from: point.date)))
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

// MARK: - Equity curve chart

struct InteractiveEquityCurveChart: View {
    let points: [WheelBacktestEquityPoint]

    private var rows: [EquityCurveRow] {
        points.map { point in
            EquityCurveRow(
                id: point.date,
                date: ChartDateParser.date(from: point.date),
                point: point
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let row = rows.last {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DateFormatters.display(row.date))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.secondaryLabel)
                    HStack(spacing: 12) {
                        Text("Strategy \(CurrencyFormatter.usd(row.point.equityUsd, fractionDigits: 0))")
                        if let buyHold = row.point.buyAndHoldEquityUsd {
                            Text("Buy & hold \(CurrencyFormatter.usd(buyHold, fractionDigits: 0))")
                        }
                    }
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surfaceElevated.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Chart(rows) { row in
                LineMark(
                    x: .value("Date", row.date),
                    y: .value("Equity", row.point.equityUsd)
                )
                .foregroundStyle(AppColors.accent)
                .interpolationMethod(.catmullRom)

                if let buyHold = row.point.buyAndHoldEquityUsd {
                    LineMark(
                        x: .value("Date", row.date),
                        y: .value("Buy & hold", buyHold)
                    )
                    .foregroundStyle(AppColors.secondaryLabel.opacity(0.7))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 180)
        }
    }
}

private struct EquityCurveRow: Identifiable {
    let id: String
    let date: Date
    let point: WheelBacktestEquityPoint
}
