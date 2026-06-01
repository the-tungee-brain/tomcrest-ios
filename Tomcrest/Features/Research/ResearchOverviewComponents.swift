import SwiftUI

// MARK: - Hero quote

struct SymbolQuoteHeroCard: View {
    let bundle: ResearchOverviewBundle

    var body: some View {
        let snapshot = bundle.snapshot

        VStack(alignment: .leading, spacing: 16) {
            Text(metadataLine(snapshot: snapshot, assetType: bundle.assetType))
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
