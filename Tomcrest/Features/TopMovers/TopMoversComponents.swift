import SwiftUI

struct TopMoversHeader: View {
    let hasMlMetrics: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Top Movers")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Token.textPrimary)
            Text(
                hasMlMetrics
                    ? "ML-ranked leaders vs the full universe"
                    : "Composite-ranked leaders vs the full universe"
            )
            .font(.subheadline)
            .foregroundStyle(Token.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MarketRegimeCard: View {
    let regimeId: String?
    let asOfDate: String?
    let updatedAt: String?
    let systemStatus: String

    private var narrative: RegimeNarrative {
        TopMoversFormatting.regimeNarrative(regimeId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MARKET ENVIRONMENT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Token.textSecondary)
                .tracking(0.6)

            Text(narrative.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Token.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(narrative.guidance)
                .font(.subheadline)
                .foregroundStyle(Token.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            regimeImpactBlock

            HStack(spacing: 8) {
                regimePill(TopMoversFormatting.riskLabel(regimeId: regimeId), tone: .accent)
                regimePill(statusPillText, tone: statusTone)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Token.textTertiary)
        }
        .appPanel(subtle: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Market environment, \(narrative.title)")
    }

    private var regimeImpactBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REGIME IMPACT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Token.textTertiary)
                .tracking(0.5)
            Text(narrative.signalImpact)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Token.textPrimary)
            Text(narrative.confidenceNote)
                .font(.footnote)
                .foregroundStyle(Token.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Token.surfaceFillSecondary.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusPillText: String {
        switch systemStatus.lowercased() {
        case "ok": "Pipeline OK"
        case "degraded": "Degraded"
        default: systemStatus.capitalized
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let asOfDate { parts.append("As of \(asOfDate)") }
        parts.append(TopMoversFormatting.relativeTime(iso: updatedAt))
        return parts.joined(separator: " · ")
    }

    private var statusTone: RegimePillTone {
        switch systemStatus.lowercased() {
        case "ok": .success
        case "degraded": .warning
        default: .danger
        }
    }

    private func regimePill(_ text: String, tone: RegimePillTone) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone.background)
            .clipShape(Capsule())
    }
}

struct CompositeModelBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(Token.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Composite Ranking Model")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Token.textPrimary)
                Text("This run ranks on composite scores only. ML probability and excess return are not shown.")
                    .font(.caption)
                    .foregroundStyle(Token.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Token.surfaceFillSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ConvictionBadge: View {
    let conviction: ConvictionDisplay

    var body: some View {
        Text(conviction.label)
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(foreground.opacity(0.14))
            .clipShape(Capsule())
            .accessibilityLabel("Conviction \(conviction.label)")
    }

    private var foreground: Color {
        switch conviction.tier {
        case .elite: Token.primary
        case .strong: AppColors.success
        case .rising: AppColors.warning
        case .mixed: Token.textSecondary
        }
    }
}

struct ContributionSparkline: View {
    let values: [Double]
    var pending: Bool = false

    var body: some View {
        Group {
            if pending || values.allSatisfy({ $0 == 0 }) {
                sparklinePlaceholder
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(sparklineColor(value))
                            .frame(
                                width: 4,
                                height: TopMoversFormatting.sparklineBarHeight(value)
                            )
                    }
                }
            }
        }
        .frame(width: 28, height: 22, alignment: .bottom)
        .accessibilityLabel(pending ? "Loading signal bars" : "Signal shape sparkline")
    }

    private var sparklinePlaceholder: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach([0.45, 0.65, 0.55, 0.35, 0.25], id: \.self) { stub in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Token.gridLine.opacity(0.85))
                    .frame(width: 4, height: max(4, 22 * stub))
            }
        }
    }

    private func sparklineColor(_ value: Double) -> Color {
        switch TopMoversFormatting.sparklineBarTier(value) {
        case .strong:
            return Token.primary.opacity(0.92)
        case .moderate:
            return Token.primary.opacity(0.55)
        case .weak:
            return AppColors.warning
        case .missing:
            return Token.gridLine
        }
    }
}

struct ScoreBreakdownView: View {
    let segments: [ScoreBreakdownSegment]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MoversSectionTitle(title: "WHY IT RANKS")

            if isLoading {
                ProgressView()
                    .controlSize(.regular)
            } else if segments.isEmpty {
                Text("Contribution profile loads from pattern intelligence.")
                    .font(.footnote)
                    .foregroundStyle(Token.textSecondary)
            } else {
                ForEach(segments) { segment in
                    contributionRow(segment)
                }
            }
        }
    }

    private func contributionRow(_ segment: ScoreBreakdownSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(segment.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Token.textPrimary)
                Spacer(minLength: 8)
                tierChip(segment.tier, label: segment.tierLabel)
            }

            segmentedBar(
                fill: segment.value,
                tier: segment.tier,
                barWidthPct: TopMoversFormatting.contributionBarWidth(
                    tier: segment.tier,
                    value: segment.value
                )
            )
        }
    }

    private func tierChip(_ tier: ContributionTier, label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tierForeground(tier))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tierForeground(tier).opacity(0.12))
            .clipShape(Capsule())
    }

    private func segmentedBar(
        fill: Double,
        tier: ContributionTier,
        barWidthPct: Double
    ) -> some View {
        let showFill = TopMoversFormatting.showsContributionFill(tier: tier, value: fill)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Token.gridLine)
                if showFill {
                    Capsule()
                        .fill(tierForeground(tier))
                        .frame(width: geo.size.width * (barWidthPct / 100))
                }
            }
        }
        .frame(height: 10)
        .accessibilityValue(Text("\(segmentTierAccessibility(tier))"))
    }

    private func segmentTierAccessibility(_ tier: ContributionTier) -> String {
        switch tier {
        case .strong: "strong contribution"
        case .moderate: "moderate contribution"
        case .weak: "weak contribution"
        case .missing: "missing contribution"
        }
    }

    private func tierForeground(_ tier: ContributionTier) -> Color {
        switch tier {
        case .strong: Token.primary.opacity(0.92)
        case .moderate: Token.primary.opacity(0.55)
        case .weak: AppColors.warning
        case .missing: Token.textTertiary
        }
    }
}

struct RegimeCompactCard: View {
    let regime: RegimeCompact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MoversSectionTitle(title: "CURRENT REGIME")
            Text(regime.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Token.textPrimary)
            Text("Impact: \(regime.impact)")
                .font(.caption)
                .foregroundStyle(Token.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Token.surfaceFillSecondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct MoverResearchInsightSection: View {
    let insight: MoverResearchInsight
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MoversRowMetrics.expandedSpacing) {
            thesisBlock
            MoversBulletListSection(
                title: "WHAT SUPPORTS THE SIGNAL",
                lines: insight.supports.map(\.label),
                style: .checkmark
            )
            MoversBulletListSection(
                title: "WHAT IS STILL MISSING",
                lines: insight.missing.map(\.label),
                style: .warning
            )
            if !insight.confirmations.isEmpty {
                MoversBulletListSection(
                    title: "NEXT CONFIRMATION TO WATCH",
                    lines: insight.confirmations.map(\.label),
                    style: .bullet
                )
            }
        }
        .opacity(isLoading ? 0.55 : 1)
    }

    private var thesisBlock: some View {
        MoversCalloutBlock {
            VStack(alignment: .leading, spacing: 10) {
                MoversSectionTitle(title: "INVESTMENT THESIS")
                Text(insight.thesis)
                    .font(.subheadline)
                    .foregroundStyle(Token.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    MoversSectionTitle(title: "DECISION SUMMARY")
                    Text(insight.decisionSummary.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Token.textPrimary)
                    Text("Reason")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Token.textSecondary)
                    ForEach(Array(insight.decisionSummary.reasons.enumerated()), id: \.offset) { _, reason in
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(Token.textPrimary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

struct TopMoverRow: View {
    let item: RankingItem
    let rankContext: RankContext
    let rowConviction: ConvictionDisplay
    let detailConviction: ConvictionDisplay
    let priceTrend: String?
    let sparkline: [Double]
    let sparklinePending: Bool
    let hasMlMetrics: Bool
    let isExpanded: Bool
    let inPortfolio: Bool
    let segments: [ScoreBreakdownSegment]
    let researchInsight: MoverResearchInsight
    let portfolioRole: String?
    let breakdownLoading: Bool
    let onToggle: () -> Void
    let onResearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 10) {
                    symbolBlock
                    Spacer(minLength: 4)
                    trailingBlock
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Token.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: Layout.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
            }
        }
        .background(isExpanded ? Token.surfaceFillSecondary.opacity(0.35) : Color.clear)
    }

    private var symbolBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(rankContext.rankLabel)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(Token.textPrimary)
                .frame(minWidth: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.symbol.uppercased())
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Token.textPrimary)

                Text(rankContext.subtitle)
                    .font(.caption)
                    .foregroundStyle(Token.textSecondary)

                if hasMlMetrics {
                    mlMetricsLine
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var mlMetricsLine: some View {
        HStack(spacing: 10) {
            if item.mlProbability != nil {
                Text("P(SPY) \(TopMoversFormatting.probabilityText(item.mlProbability))")
            }
            if item.expectedExcessReturn != nil {
                Text("Excess \(TopMoversFormatting.excessText(item.expectedExcessReturn))")
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(Token.textTertiary)
    }

    private var trailingBlock: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ConvictionBadge(conviction: rowConviction)
            ContributionSparkline(values: sparkline, pending: sparklinePending)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: MoversRowMetrics.expandedSpacing) {
            MoversExpandedDivider()

            detailHeader

            MoverResearchInsightSection(
                insight: researchInsight,
                isLoading: breakdownLoading
            )

            ScoreBreakdownView(segments: segments, isLoading: breakdownLoading)

            RegimeCompactCard(regime: researchInsight.regimeCompact)

            SymbolInvestigateActionBar(
                symbol: item.symbol,
                onResearch: onResearch
            )
        }
        .padding(.horizontal, MoversRowMetrics.expandedHorizontalPadding)
        .padding(.bottom, MoversRowMetrics.expandedBottomPadding)
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ConvictionBadge(conviction: rowConviction)
                if detailConviction.tier != rowConviction.tier {
                    Text("Signal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Token.textTertiary)
                    ConvictionBadge(conviction: detailConviction)
                }
                if let priceTrend {
                    Text("· Price \(priceTrend)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Token.textSecondary)
                }
            }

            if let portfolioRole {
                Text("Portfolio role: \(portfolioRole)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Token.textSecondary)
            } else if inPortfolio {
                Label("In model portfolio", systemImage: "briefcase.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Token.textSecondary)
            }

            #if DEBUG
            Text("Final score \(item.finalScore, format: .number.precision(.fractionLength(2)))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Token.textTertiary)
            #endif
        }
    }

}

private enum RegimePillTone {
    case accent, success, warning, danger

    var foreground: Color {
        switch self {
        case .accent: Token.primary
        case .success: AppColors.success
        case .warning: AppColors.warning
        case .danger: AppColors.error
        }
    }

    var background: Color {
        foreground.opacity(0.14)
    }
}
