import SwiftUI

// MARK: - Hero quote

struct SymbolQuoteHeroCard: View {
    let snapshot: ResearchSnapshot
    let assetType: String?

    init(snapshot: ResearchSnapshot, assetType: String?) {
        self.snapshot = snapshot
        self.assetType = assetType
    }

    init(bundle: ResearchOverviewBundle) {
        self.snapshot = bundle.snapshot
        self.assetType = bundle.assetType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(metadataLine(snapshot: snapshot, assetType: assetType))
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(CurrencyFormatter.usd(snapshot.price))
                    .font(AppTypography.heroMetric)
                    .foregroundStyle(AppColors.label)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text(CurrencyFormatter.percent(snapshot.changePct))
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(changeColor(snapshot.changePct))
            }

            AppMetricStrip(items: quoteStripItems(snapshot: snapshot))
        }
        .appHeroPanel()
    }

    private func quoteStripItems(snapshot: ResearchSnapshot) -> [(label: String, value: String)] {
        var items: [(String, String)] = []
        if let pe = snapshot.peRatio {
            items.append(("P/E", String(format: "%.1f", pe)))
        }
        if let yield = snapshot.dividendYieldPct {
            items.append(("Yield", String(format: "%.2f%%", yield)))
        }
        items.append(("Mkt cap", snapshot.marketCap))
        if items.count < 3, let range = snapshot.range52w {
            items.append(("52W", range))
        }
        return Array(items.prefix(3))
    }

    private func metadataLine(snapshot: ResearchSnapshot, assetType: String?) -> String {
        let parts = [snapshot.sector, snapshot.country].filter { !$0.isEmpty }
        if parts.isEmpty {
            return AssetTypeLabel.display(assetType)
        }
        return parts.joined(separator: " · ")
    }

    private func changeColor(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

// MARK: - Events

struct ResearchEventsTeaserCard: View {
    let events: [EventTimelineEntry]

    var body: some View {
        AppScreenSection(title: "Recent events") {
            if events.isEmpty {
                AppEmptyMessage(
                    message: "No recent SEC or earnings events found.",
                    systemImage: "calendar"
                )
            } else {
                AppGroupedList {
                    ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { index, event in
                        eventRow(event)

                        if index < min(events.count, 3) - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }

    private func eventRow(_ event: EventTimelineEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(eventKindLabel(event.kind))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                Text(DateFormatters.abbreviatedDay(from: event.date))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.tertiaryLabel)
                Spacer(minLength: 8)
            }

            Text(event.title)
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = event.detail, !detail.isEmpty {
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eventKindLabel(_ kind: ResearchEventKind) -> String {
        switch kind {
        case .trade: "Trade"
        case .filing: "Filing"
        case .earnings: "Earnings"
        case .news: "News"
        case .pressRelease: "Press release"
        case .macro: "Macro"
        case .price: "Price"
        case .dividend: "Dividend"
        case .unknown: "Event"
        }
    }
}

// MARK: - Trading Bias

struct TradingBiasCard: View {
    let tradingBias: TradingBiasResponse

    var body: some View {
        AppScreenSection(
            title: "Trading Bias",
            footnote: "Short-term daily bias · \(tradingBias.horizon)"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                biasHeader
                factorGrid
                levelsGrid

                if let invalidation = tradingBias.invalidation, !invalidation.isEmpty {
                    Label(invalidation, systemImage: "shield.checkered")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                alignmentRow

                if !tradingBias.dataGaps.isEmpty {
                    AppInlineBanner(
                        message: "Data gaps: \(tradingBias.dataGaps.joined(separator: "; "))",
                        tone: .neutral
                    )
                }
            }
            .padding(16)
            .background(biasColor.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(biasColor.opacity(0.24), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var biasHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Short-term daily bias")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(biasColor)
                    .frame(width: 10, height: 10)
                Text(tradingBias.bias.rawValue)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(biasColor)
                Text("\(tradingBias.confidence.rawValue) confidence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Text("Educational signal based on daily price, market context, relative strength, volume, and levels.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            Text("Action: \(tradingBias.action.rawValue)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
        }
    }

    private var factorGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            factorPanel(
                title: "Bullish evidence",
                items: tradingBias.bullishFactors,
                color: AppColors.success
            )
            factorPanel(
                title: "Bearish evidence",
                items: tradingBias.bearishFactors,
                color: AppColors.danger
            )
        }
    }

    private var levelsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            levelTile(title: "Support", value: tradingBias.levels.support)
            levelTile(title: "Resistance", value: tradingBias.levels.resistance)
            levelTile(title: "Breakout", value: tradingBias.levels.breakoutLevel)
            levelTile(title: "Stop invalid", value: tradingBias.levels.stopInvalidLevel)
        }
    }

    private var alignmentRow: some View {
        FlowTagRow(items: [
            "Market: \(tradingBias.alignment.marketRegime.rawValue)",
            "Relative strength: \(tradingBias.alignment.relativeStrength.rawValue)",
            "Structure: \(tradingBias.alignment.patternTrend.rawValue)",
            "Volume: \(tradingBias.alignment.volume.rawValue)",
            "Catalyst: \(tradingBias.alignment.catalyst.rawValue)",
        ])
    }

    private var biasColor: Color {
        switch tradingBias.bias {
        case .bullish: AppColors.success
        case .neutral: AppColors.label
        case .bearish: AppColors.danger
        }
    }

    private func factorPanel(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            if items.isEmpty {
                Text("No strong factors surfaced.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            } else {
                ForEach(items.prefix(3), id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(AppColors.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.secondaryFill.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func levelTile(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value.map { CurrencyFormatter.usd($0) } ?? "—")
                .font(AppTypography.monoSubheadlineSemibold)
                .foregroundStyle(AppColors.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct FlowTagRow: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.secondaryLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppColors.insetSurface)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 1)
        }
    }
}

// MARK: - Performance

struct SymbolPerformanceCard: View {
    let performance: PerformanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppMetricStrip(items: [
                ("1 month", performance.oneMonth),
                ("3 months", performance.threeMonth),
                ("1 year", performance.oneYear),
            ])

            Text("\(performance.trendLabel) · \(performance.volatilityNote)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)
        }
        // Plain metrics inside AppScreenSection("Performance Evidence") — no nested panel.
    }
}

// MARK: - Signals

struct SymbolSignalsCard: View {
    let signals: [IntelligenceSignal]

    var body: some View {
        AppGroupedList {
            ForEach(Array(signals.prefix(5).enumerated()), id: \.element.id) { index, signal in
                Text(signal.message)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.label)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                if index < min(signals.count, 5) - 1 {
                    AppGroupedDivider()
                }
            }
        }
    }
}

// MARK: - Loading

struct ResearchOverviewLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            skeletonBlock(height: 220)
            skeletonBlock(height: 88)
            skeletonBlock(height: 120)
        }
        .redacted(reason: .placeholder)
    }

    private func skeletonBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.secondaryBackground)
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
    }
}
