import SwiftUI

// MARK: - Entry card (Analysis tab)

struct ChartIntelligenceEntryCard: View {
    let intelligence: ChartIntelligencePayload

    private var subtitle: String {
        var parts: [String] = []
        if !(intelligence.supportZones ?? []).isEmpty { parts.append("Support") }
        if !(intelligence.resistanceZones ?? []).isEmpty { parts.append("Resistance") }
        if intelligence.fibChannel?.lines?.isEmpty == false { parts.append("Fib channel") }
        if !(intelligence.breakoutEvents ?? []).isEmpty { parts.append("Breakouts") }
        if !(intelligence.trendlines ?? []).isEmpty { parts.append("Trend / SMA") }
        let joined = parts.isEmpty ? "Structure overlays" : parts.joined(separator: " · ")
        return "\(joined) · 3 month daily chart"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title3)
                .foregroundStyle(AppColors.accentHighlight)
                .frame(width: 36, height: 36)
                .background(AppColors.accentMuted.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Open chart intelligence map")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .padding(14)
        .background(AppColors.surfaceElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }
}

// MARK: - Dedicated chart screen

struct ChartIntelligenceChartScreen: View {
    @Environment(AuthSession.self) private var auth

    let symbol: String
    let intelligence: ChartIntelligencePayload

    @State private var chart: StockChartPayload?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                if isLoading, chart == nil {
                    ProgressView("Loading chart…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let errorMessage {
                    AppInlineBanner(message: errorMessage, tone: .error)
                } else if let points = chart?.data, points.count >= 2 {
                    ChartIntelligenceLabeledChartView(
                        points: points,
                        intelligence: intelligence
                    )

                    ChartIntelligenceLegendPanel(intelligence: intelligence)

                    Text(
                        "Overlays are computed from daily structure. Educational context only — not investment advice."
                    )
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .lineSpacing(2)
                } else {
                    AppEmptyMessage(
                        message: "Not enough price data to draw this chart.",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
            }
        }
        .navigationTitle("Chart intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadChart()
        }
    }

    private func loadChart() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let accessToken = auth.accessToken else {
            errorMessage = "Sign in to load chart data."
            return
        }

        do {
            chart = try await ResearchService.fetchStockChart(
                symbol: symbol,
                accessToken: accessToken,
                period: "3mo",
                interval: "1d"
            )
        } catch {
            chart = nil
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Labeled canvas chart

private struct ChartIntelligenceLabeledChartView: View {
    let points: [StockChartPoint]
    let intelligence: ChartIntelligencePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("3M · Daily · Labeled overlays")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            GeometryReader { proxy in
                Canvas { context, size in
                    let layout = ChartIntelligenceLayout(points: points, size: size)
                    drawPrice(in: &context, layout: layout)
                    drawZones(in: &context, layout: layout)
                    drawLines(in: &context, layout: layout)
                    drawBreakouts(in: &context, layout: layout)
                }
            }
            .frame(height: 300)
            .background(AppColors.secondaryBackground.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.panelBorder, lineWidth: 1)
            }
        }
        .appPanel(subtle: true)
    }

    private func drawPrice(in context: inout GraphicsContext, layout: ChartIntelligenceLayout) {
        guard points.count >= 2 else { return }
        var path = Path()
        for (index, point) in points.enumerated() {
            let location = layout.point(index: index, price: point.close)
            if index == 0 {
                path.move(to: location)
            } else {
                path.addLine(to: location)
            }
        }
        context.stroke(
            path,
            with: .color(AppColors.label.opacity(0.22)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawZones(in context: inout GraphicsContext, layout: ChartIntelligenceLayout) {
        let groups: [(zones: [ChartIntelligenceZone]?, fill: Color, stroke: Color, prefix: String)] = [
            (intelligence.supportZones, AppColors.success.opacity(0.14), AppColors.success, "Support"),
            (intelligence.resistanceZones, AppColors.error.opacity(0.14), AppColors.error, "Resistance"),
        ]

        for (zones, fill, stroke, prefix) in groups {
            for (index, zone) in (zones ?? []).prefix(2).enumerated() {
                guard let low = zone.priceLow, let high = zone.priceHigh else { continue }
                let rect = layout.rect(fromPrice: high, toPrice: low)
                context.fill(Path(rect), with: .color(fill))
                context.stroke(Path(rect), with: .color(stroke.opacity(0.55)), lineWidth: 1)

                let label = zoneLabel(prefix: prefix, index: index, count: (zones ?? []).count, low: low, high: high)
                layout.drawPillLabel(
                    label,
                    at: CGPoint(x: 6, y: rect.midY),
                    color: stroke,
                    in: &context,
                    anchor: .leading
                )
            }
        }
    }

    private func drawLines(in context: inout GraphicsContext, layout: ChartIntelligenceLayout) {
        for line in intelligence.trendlines ?? [] {
            guard let mapped = layout.mappedLine(line), mapped.count >= 2 else { continue }
            let style = line.style ?? ""
            let ratio = line.ratio ?? -1
            let (color, dash, width): (Color, [CGFloat], CGFloat) = {
                if style == "fib_channel" {
                    return (
                        AppColors.warning.opacity(ratio == 0.5 ? 0.9 : 0.45),
                        ratio == 0 || ratio == 1 ? [] : [4, 4],
                        ratio == 0.5 ? 1.5 : 1
                    )
                }
                if style.hasPrefix("sma") {
                    return (smaColor(style), [], 1)
                }
                return (AppColors.secondaryLabel.opacity(0.75), [6, 4], 1.5)
            }()

            var path = Path()
            path.move(to: mapped[0])
            for point in mapped.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: width, dash: dash)
            )

            if let last = mapped.last {
                let title = line.label ?? defaultLineLabel(style: style, ratio: ratio)
                layout.drawPillLabel(
                    title,
                    at: CGPoint(x: layout.size.width - 6, y: last.y),
                    color: color,
                    in: &context,
                    anchor: .trailing
                )
            }
        }
    }

    private func drawBreakouts(in context: inout GraphicsContext, layout: ChartIntelligenceLayout) {
        for event in intelligence.breakoutEvents ?? [] {
            let barIndex = event.barIndex ?? event.date.flatMap { layout.index(for: $0) }
            guard let barIndex else { continue }
            let price = event.price ?? points[safe: barIndex]?.close ?? 0
            let center = layout.point(index: barIndex, price: price)
            let failed = event.kind.contains("failed")
            let color: Color = failed ? AppColors.error : AppColors.success

            let marker = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: marker), with: .color(color))
            context.stroke(Path(ellipseIn: marker), with: .color(AppColors.background), lineWidth: 1.5)

            let label = event.label ?? (failed ? "Failed" : "Breakout")
            layout.drawPillLabel(
                label,
                at: CGPoint(x: center.x, y: center.y - 14),
                color: color,
                in: &context,
                anchor: .center
            )
        }
    }

    private func zoneLabel(prefix: String, index: Int, count: Int, low: Double, high: Double) -> String {
        let name = count > 1 ? "\(prefix) \(index + 1)" : prefix
        return "\(name) \(CurrencyFormatter.usd(low, fractionDigits: 2))–\(CurrencyFormatter.usd(high, fractionDigits: 2))"
    }

    private func smaColor(_ style: String) -> Color {
        switch style {
        case "sma20": Color(red: 0.22, green: 0.74, blue: 0.97)
        case "sma50": Color(red: 0.65, green: 0.55, blue: 0.98)
        case "sma200": Color(red: 0.96, green: 0.62, blue: 0.04)
        default: AppColors.accentHighlight.opacity(0.7)
        }
    }

    private func defaultLineLabel(style: String, ratio: Double) -> String {
        if style == "fib_channel" {
            if ratio == 0 { return "Fib 0%" }
            if ratio == 0.5 { return "Fib 50%" }
            if ratio >= 1 { return "Fib 100%" }
            return "Fib \(Int(ratio * 100))%"
        }
        if style.hasPrefix("sma") {
            switch style {
            case "sma20": return "SMA 20"
            case "sma50": return "SMA 50"
            case "sma200": return "SMA 200"
            default: return style.uppercased()
            }
        }
        return "Trendline"
    }
}

// MARK: - Legend

private struct ChartIntelligenceLegendPanel: View {
    let intelligence: ChartIntelligencePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you're seeing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                ForEach(legendRows) { row in
                    HStack(alignment: .top, spacing: 10) {
                        legendSwatch(row)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.label)
                            if let detail = row.detail {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .appPanel(subtle: true)
    }

    private var legendRows: [LegendRow] {
        var rows: [LegendRow] = []

        for (index, zone) in (intelligence.supportZones ?? []).prefix(2).enumerated() {
            guard let low = zone.priceLow, let high = zone.priceHigh else { continue }
            rows.append(
                LegendRow(
                    id: "support-\(index)",
                    title: (intelligence.supportZones ?? []).count > 1 ? "Support \(index + 1)" : "Support",
                    detail: "Green band where price has bounced · \(priceRange(low, high))",
                    kind: .band,
                    color: AppColors.success
                )
            )
        }

        for (index, zone) in (intelligence.resistanceZones ?? []).prefix(2).enumerated() {
            guard let low = zone.priceLow, let high = zone.priceHigh else { continue }
            rows.append(
                LegendRow(
                    id: "resistance-\(index)",
                    title: (intelligence.resistanceZones ?? []).count > 1 ? "Resistance \(index + 1)" : "Resistance",
                    detail: "Red band where rallies have stalled · \(priceRange(low, high))",
                    kind: .band,
                    color: AppColors.error
                )
            )
        }

        let smaStyles = Set((intelligence.trendlines ?? []).compactMap(\.style).filter { $0.hasPrefix("sma") })
        for style in ["sma20", "sma50", "sma200"] where smaStyles.contains(style) {
            rows.append(
                LegendRow(
                    id: style,
                    title: smaTitle(style),
                    detail: "Moving average overlay on the daily chart.",
                    kind: .line,
                    color: AppColors.accentHighlight,
                    dashed: false
                )
            )
        }

        if (intelligence.trendlines ?? []).contains(where: { ($0.style ?? "") == "trendline" || ($0.style ?? "").isEmpty && $0.startDate != nil }) {
            rows.append(
                LegendRow(
                    id: "trendline",
                    title: "Structure trendline",
                    detail: "Dashed line through recent swing structure.",
                    kind: .line,
                    color: AppColors.secondaryLabel,
                    dashed: true
                )
            )
        }

        if intelligence.fibChannel?.lines?.isEmpty == false {
            rows.append(
                LegendRow(
                    id: "fib",
                    title: "Fib channel",
                    detail: intelligence.fibChannel?.summary ?? "Parallel amber rails from swing highs and lows.",
                    kind: .line,
                    color: AppColors.warning,
                    dashed: true
                )
            )
        }

        for event in intelligence.breakoutEvents ?? [] {
            let failed = event.kind.contains("failed")
            rows.append(
                LegendRow(
                    id: "breakout-\(event.date ?? event.label ?? UUID().uuidString)",
                    title: event.label ?? "Breakout event",
                    detail: failed
                        ? "Price pierced a level then reversed — often a trap."
                        : "Price broke a level and held on follow-through.",
                    kind: .marker,
                    color: failed ? AppColors.error : AppColors.success
                )
            )
        }

        return rows
    }

    @ViewBuilder
    private func legendSwatch(_ row: LegendRow) -> some View {
        switch row.kind {
        case .band:
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(row.color.opacity(0.25))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(row.color.opacity(0.7), lineWidth: 1)
                }
                .frame(height: 10)
        case .line:
            Rectangle()
                .fill(row.color)
                .frame(height: 2)
                .frame(maxWidth: 22)
                .overlay {
                    if row.dashed {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                            .foregroundStyle(row.color)
                    }
                }
        case .marker:
            Circle()
                .fill(row.color)
                .frame(width: 8, height: 8)
        }
    }

    private func priceRange(_ low: Double, _ high: Double) -> String {
        "\(CurrencyFormatter.usd(low, fractionDigits: 2)) – \(CurrencyFormatter.usd(high, fractionDigits: 2))"
    }

    private func smaTitle(_ style: String) -> String {
        switch style {
        case "sma20": return "SMA 20"
        case "sma50": return "SMA 50"
        case "sma200": return "SMA 200"
        default: return style.uppercased()
        }
    }
}

private struct LegendRow: Identifiable {
    enum Kind { case band, line, marker }

    let id: String
    let title: String
    let detail: String?
    let kind: Kind
    let color: Color
    var dashed: Bool = false
}

// MARK: - Layout helpers

private struct ChartIntelligenceLayout {
    let size: CGSize
    let minPrice: Double
    let maxPrice: Double
    private let dateIndex: [String: Int]
    private let plotInsets = EdgeInsets(top: 18, leading: 8, bottom: 18, trailing: 72)

    init(points: [StockChartPoint], size: CGSize) {
        self.size = size
        let lows = points.map(\.low)
        let highs = points.map(\.high)
        minPrice = (lows.min() ?? 0) * 0.992
        maxPrice = (highs.max() ?? 1) * 1.008
        var map: [String: Int] = [:]
        for (index, point) in points.enumerated() {
            map[String(point.date.prefix(10))] = index
        }
        dateIndex = map
    }

    private var plotSize: CGSize {
        CGSize(
            width: max(size.width - plotInsets.leading - plotInsets.trailing, 1),
            height: max(size.height - plotInsets.top - plotInsets.bottom, 1)
        )
    }

    func index(for date: String) -> Int? {
        dateIndex[String(date.prefix(10))]
    }

    func point(index: Int, price: Double) -> CGPoint {
        let count = max(dateIndex.count, 2)
        let xStep = plotSize.width / CGFloat(count - 1)
        let x = plotInsets.leading + CGFloat(index) * xStep
        let span = max(maxPrice - minPrice, 0.01)
        let normalized = (price - minPrice) / span
        let y = plotInsets.top + plotSize.height * CGFloat(1 - normalized)
        return CGPoint(x: x, y: y)
    }

    func rect(fromPrice top: Double, toPrice bottom: Double) -> CGRect {
        let topPoint = point(index: 0, price: top)
        let bottomPoint = point(index: 0, price: bottom)
        return CGRect(
            x: plotInsets.leading,
            y: topPoint.y,
            width: plotSize.width,
            height: max(bottomPoint.y - topPoint.y, 1)
        )
    }

    func mappedLine(_ line: ChartIntelligenceTrendline) -> [CGPoint]? {
        if let series = line.points, !series.isEmpty {
            let mapped = series.compactMap { point -> CGPoint? in
                guard let index = index(for: point.date) else { return nil }
                return self.point(index: index, price: point.price)
            }
            return mapped.count >= 2 ? mapped : nil
        }
        if let startDate = line.startDate,
           let endDate = line.endDate,
           let startPrice = line.startPrice,
           let endPrice = line.endPrice,
           let startIndex = index(for: startDate),
           let endIndex = index(for: endDate) {
            return [
                point(index: startIndex, price: startPrice),
                point(index: endIndex, price: endPrice),
            ]
        }
        return nil
    }

    func drawPillLabel(
        _ text: String,
        at position: CGPoint,
        color: Color,
        in context: inout GraphicsContext,
        anchor: UnitPoint
    ) {
        let label = Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
        let resolved = context.resolve(label)
        context.draw(resolved, at: position, anchor: anchor)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
