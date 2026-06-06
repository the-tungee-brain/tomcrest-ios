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
                    ForEach(Array(events.prefix(3).enumerated()), id: \.element.id) { index, event in
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
        // Plain metrics inside AppScreenSection("Performance") — no nested panel.
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
