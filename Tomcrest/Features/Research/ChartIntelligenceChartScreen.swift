import SwiftUI
import WebKit

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
                    ChartIntelligenceWebChartView(
                        points: points,
                        intelligence: intelligence
                    )

                    Text(
                        "Overlays are computed from daily structure. Educational context only — not investment advice. Charts by TradingView."
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
        .appPushedScreenCanvas()
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

// MARK: - Interactive web chart (TradingView Lightweight Charts)

private struct ChartIntelligenceCrosshairPoint: Equatable {
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int

    init(date: String, open: Double, high: Double, low: Double, close: Double, volume: Int) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }

    init(point: StockChartPoint) {
        date = point.date
        open = point.open
        high = point.high
        low = point.low
        close = point.close
        volume = point.volume
    }
}

private struct ChartIntelligenceWebChartView: View {
    let points: [StockChartPoint]
    let intelligence: ChartIntelligencePayload

    @Environment(\.colorScheme) private var colorScheme
    @State private var crosshairPoint: ChartIntelligenceCrosshairPoint?
    @State private var latestPoint: ChartIntelligenceCrosshairPoint?

    private var displayPoint: ChartIntelligenceCrosshairPoint? {
        crosshairPoint ?? latestPoint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let displayPoint {
                crosshairReadout(displayPoint, scrubbing: crosshairPoint != nil)
            }

            GeometryReader { proxy in
                ChartIntelligenceWebChartRepresentable(
                    points: points,
                    intelligence: intelligence,
                    colorScheme: colorScheme,
                    containerSize: proxy.size,
                    onCrosshairChange: { point in
                        crosshairPoint = point
                    }
                )
            }
            .frame(height: 360)
            .frame(maxWidth: .infinity)

            ChartIntelligenceBottomLegend(intelligence: intelligence)

            Text("Pinch to zoom · drag to pan")
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .onAppear {
            latestPoint = points.last.map(ChartIntelligenceCrosshairPoint.init(point:))
        }
        .onChange(of: points.count) { _, _ in
            crosshairPoint = nil
            latestPoint = points.last.map(ChartIntelligenceCrosshairPoint.init(point:))
        }
    }

    @ViewBuilder
    private func crosshairReadout(_ point: ChartIntelligenceCrosshairPoint, scrubbing: Bool) -> some View {
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

private struct ChartIntelligenceWebChartRepresentable: UIViewRepresentable {
    let points: [StockChartPoint]
    let intelligence: ChartIntelligencePayload
    let colorScheme: ColorScheme
    let containerSize: CGSize
    let onCrosshairChange: (ChartIntelligenceCrosshairPoint?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCrosshairChange: onCrosshairChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "crosshair")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onCrosshairChange = onCrosshairChange

        guard containerSize.width > 0, containerSize.height > 0 else { return }

        guard let htmlURL = Bundle.main.url(
            forResource: "chart-intelligence",
            withExtension: "html",
            subdirectory: "ChartIntelligence"
        ) ?? Bundle.main.url(forResource: "chart-intelligence", withExtension: "html") else {
            return
        }
        let folderURL = htmlURL.deletingLastPathComponent()

        let payload = ChartWebRenderPayload(
            candles: points.map(ChartWebCandle.init(point:)),
            intelligence: intelligence,
            theme: ChartWebTheme(colorScheme: colorScheme)
        )

        guard let jsonData = try? JSONEncoder().encode(payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let dataSignature = "\(points.count)-\(points.last?.date ?? "")-\(colorScheme)"
        context.coordinator.pendingSize = containerSize

        if context.coordinator.loadedSignature != dataSignature {
            context.coordinator.loadedSignature = dataSignature
            context.coordinator.lastDataSignature = nil
            context.coordinator.pendingPayload = jsonString
            context.coordinator.isReady = false
            webView.loadFileURL(htmlURL, allowingReadAccessTo: folderURL)
        } else if context.coordinator.isReady {
            context.coordinator.renderOrResize(
                jsonString,
                dataSignature: dataSignature,
                size: containerSize,
                in: webView
            )
        } else {
            context.coordinator.pendingPayload = jsonString
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var webView: WKWebView?
        var loadedSignature: String?
        var pendingPayload: String?
        var pendingSize: CGSize = .zero
        var lastDataSignature: String?
        var lastRenderedSize: CGSize = .zero
        var isReady = false
        var onCrosshairChange: (ChartIntelligenceCrosshairPoint?) -> Void

        init(onCrosshairChange: @escaping (ChartIntelligenceCrosshairPoint?) -> Void) {
            self.onCrosshairChange = onCrosshairChange
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "crosshair",
                  let body = message.body as? [String: Any] else { return }

            if body["clear"] as? Bool == true {
                onCrosshairChange(nil)
                return
            }

            guard let date = body["date"] as? String,
                  let open = body["open"] as? Double,
                  let high = body["high"] as? Double,
                  let low = body["low"] as? Double,
                  let close = body["close"] as? Double else {
                onCrosshairChange(nil)
                return
            }

            let volume = body["volume"] as? Int ?? 0
            onCrosshairChange(
                ChartIntelligenceCrosshairPoint(
                    date: date,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: volume
                )
            )
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            guard let pendingPayload else { return }
            DispatchQueue.main.async { [weak self, weak webView] in
                guard let self, let webView else { return }
                let signature = self.loadedSignature ?? ""
                self.renderOrResize(
                    pendingPayload,
                    dataSignature: signature,
                    size: self.pendingSize,
                    in: webView
                )
            }
        }

        func renderOrResize(
            _ jsonString: String,
            dataSignature: String,
            size: CGSize,
            in webView: WKWebView
        ) {
            let width = max(size.width, webView.bounds.width)
            let height = max(size.height, webView.bounds.height)
            guard width > 0, height > 0 else { return }

            if lastDataSignature != dataSignature {
                lastDataSignature = dataSignature
                lastRenderedSize = CGSize(width: width, height: height)
                let script = "window.renderChart(\(jsonString), \(width), \(height));"
                webView.evaluateJavaScript(script) { _, error in
                    if let error {
                        NSLog("Chart intelligence render failed: \(error.localizedDescription)")
                    }
                }
                return
            }

            if lastRenderedSize != CGSize(width: width, height: height) {
                resize(width: width, height: height, in: webView)
            }
        }

        func resize(width: CGFloat, height: CGFloat, in webView: WKWebView) {
            guard width > 0, height > 0 else { return }
            lastRenderedSize = CGSize(width: width, height: height)
            let script = "window.resizeChart(\(width), \(height));"
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    NSLog("Chart intelligence resize failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

private struct ChartWebCandle: Encodable {
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int

    init(point: StockChartPoint) {
        date = point.date
        open = point.open
        high = point.high
        low = point.low
        close = point.close
        volume = point.volume
    }
}

private struct ChartWebTheme: Encodable {
    let background: String
    let text: String
    let border: String
    let gridLine: String
    let accent: String

    init(colorScheme: ColorScheme) {
        background = ChartWebTheme.hex(Token.background, colorScheme: colorScheme)
        text = ChartWebTheme.hex(Token.textPrimary, colorScheme: colorScheme)
        border = "rgba(255, 255, 255, 0.12)"
        gridLine = "rgba(255, 255, 255, 0.06)"
        accent = ChartWebTheme.hex(Token.primaryHighlight, colorScheme: colorScheme)
    }

    private static func hex(_ color: Color, colorScheme: ColorScheme) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

private struct ChartWebRenderPayload: Encodable {
    let candles: [ChartWebCandle]
    let intelligence: ChartIntelligencePayload
    let theme: ChartWebTheme
}

// MARK: - Bottom overlay labels

private struct ChartIntelligenceBottomLegend: View {
    let intelligence: ChartIntelligencePayload

    var body: some View {
        let items = legendItems
        if items.isEmpty {
            EmptyView()
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 108), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(items) { item in
                    legendChip(item)
                }
            }
        }
    }

    private func legendChip(_ item: OverlayLegendItem) -> some View {
        HStack(spacing: 6) {
            legendSwatch(item)
            Text(item.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.label)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppColors.surfaceElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func legendSwatch(_ item: OverlayLegendItem) -> some View {
        switch item.kind {
        case .band:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(item.color.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(item.color.opacity(0.8), lineWidth: 1)
                }
                .frame(width: 12, height: 8)
        case .line:
            Rectangle()
                .fill(item.color)
                .frame(width: 12, height: item.dashed ? 0 : 2)
                .overlay {
                    if item.dashed {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [2, 2]))
                            .foregroundStyle(item.color)
                            .frame(height: 2)
                    }
                }
        case .marker:
            Circle()
                .fill(item.color)
                .frame(width: 7, height: 7)
        }
    }

    private var legendItems: [OverlayLegendItem] {
        var items: [OverlayLegendItem] = []
        var seenSma = Set<String>()
        var structureTrendlineCount = 0

        for line in intelligence.trendlines ?? [] {
            let style = line.style ?? ""
            if style.hasPrefix("sma") {
                guard seenSma.insert(style).inserted else { continue }
                items.append(
                    OverlayLegendItem(
                        id: style,
                        label: smaTitle(style),
                        kind: .line,
                        color: smaColor(style),
                        dashed: false
                    )
                )
                continue
            }
            if line.points?.isEmpty == false || line.startDate != nil {
                structureTrendlineCount += 1
            }
        }

        if structureTrendlineCount > 0 {
            items.append(
                OverlayLegendItem(
                    id: "trendline",
                    label: structureTrendlineCount > 1 ? "Trendlines (\(structureTrendlineCount))" : "Trendline",
                    kind: .line,
                    color: AppColors.secondaryLabel,
                    dashed: true
                )
            )
        }

        for (index, zone) in (intelligence.supportZones ?? []).prefix(2).enumerated() {
            guard let low = zone.priceLow, let high = zone.priceHigh else { continue }
            let title = (intelligence.supportZones ?? []).count > 1 ? "Support \(index + 1)" : "Support"
            items.append(
                OverlayLegendItem(
                    id: "support-\(index)",
                    label: "\(title) · \(priceRange(low, high))",
                    kind: .band,
                    color: AppColors.success
                )
            )
        }

        for (index, zone) in (intelligence.resistanceZones ?? []).prefix(2).enumerated() {
            guard let low = zone.priceLow, let high = zone.priceHigh else { continue }
            let title = (intelligence.resistanceZones ?? []).count > 1 ? "Resistance \(index + 1)" : "Resistance"
            items.append(
                OverlayLegendItem(
                    id: "resistance-\(index)",
                    label: "\(title) · \(priceRange(low, high))",
                    kind: .band,
                    color: AppColors.error
                )
            )
        }

        if intelligence.fibChannel?.lines?.isEmpty == false {
            items.append(
                OverlayLegendItem(
                    id: "fib",
                    label: "Fib channel",
                    kind: .line,
                    color: AppColors.warning,
                    dashed: true
                )
            )
        }

        for event in intelligence.breakoutEvents ?? [] {
            items.append(
                OverlayLegendItem(
                    id: "breakout-\(event.date ?? event.label ?? UUID().uuidString)",
                    label: event.label ?? "Breakout",
                    kind: .marker,
                    color: event.kind.contains("failed") ? AppColors.error : AppColors.success
                )
            )
        }

        return items
    }

    private func priceRange(_ low: Double, _ high: Double) -> String {
        "\(CurrencyFormatter.usd(low, fractionDigits: 2))–\(CurrencyFormatter.usd(high, fractionDigits: 2))"
    }

    private func smaTitle(_ style: String) -> String {
        switch style {
        case "sma20": return "SMA 20"
        case "sma50": return "SMA 50"
        case "sma200": return "SMA 200"
        default: return style.uppercased()
        }
    }

    private func smaColor(_ style: String) -> Color {
        switch style {
        case "sma20": Color(red: 0.22, green: 0.74, blue: 0.97)
        case "sma50": Color(red: 0.65, green: 0.55, blue: 0.98)
        case "sma200": Color(red: 0.96, green: 0.62, blue: 0.04)
        default: AppColors.accentHighlight
        }
    }
}

private struct OverlayLegendItem: Identifiable {
    enum Kind { case band, line, marker }

    let id: String
    let label: String
    let kind: Kind
    let color: Color
    var dashed: Bool = false
}

