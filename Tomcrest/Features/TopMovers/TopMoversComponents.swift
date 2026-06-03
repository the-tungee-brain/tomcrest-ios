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

struct ScoreBreakdownView: View {
    let segments: [ScoreBreakdownSegment]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHY IT RANKS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Token.textSecondary)
                .tracking(0.6)

            if isLoading {
                ProgressView()
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if segments.isEmpty {
                Text("Contribution bars load from the latest pattern intelligence for this symbol.")
                    .font(.footnote)
                    .foregroundStyle(Token.textSecondary)
            } else {
                ForEach(segments) { segment in
                    scoreBar(segment)
                }
            }
        }
    }

    private func scoreBar(_ segment: ScoreBreakdownSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(segment.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Token.textPrimary)
                Spacer()
                Text("\(Int((segment.value * 100).rounded()))")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Token.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Token.gridLine)
                    Capsule()
                        .fill(Token.primary.opacity(0.88))
                        .frame(width: max(4, geo.size.width * segment.value))
                }
            }
            .frame(height: 6)
        }
    }
}

struct KeySignalsView: View {
    let signals: [KeySignalItem]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KEY SIGNALS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Token.textSecondary)
                .tracking(0.6)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if signals.isEmpty {
                Text("Signals appear when pattern intelligence is available.")
                    .font(.footnote)
                    .foregroundStyle(Token.textSecondary)
            } else {
                ForEach(signals) { signal in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: signal.isPositive ? "checkmark.circle.fill" : "minus.circle")
                            .font(.subheadline)
                            .foregroundStyle(
                                signal.isPositive ? AppColors.success : Token.textTertiary
                            )
                        Text(signal.label)
                            .font(.subheadline)
                            .foregroundStyle(Token.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct TopMoverRow: View {
    let item: RankingItem
    let companyName: String?
    let percentileLabel: String
    let rowTrend: TrendDisplay
    let detailTrend: TrendDisplay?
    let hasMlMetrics: Bool
    let isExpanded: Bool
    let inPortfolio: Bool
    let segments: [ScoreBreakdownSegment]
    let signals: [KeySignalItem]
    let signalStrength: String?
    let insightHeadline: String?
    let breakdownLoading: Bool
    let onToggle: () -> Void
    let onResearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
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
            Text("\(item.rank)")
                .font(.body.weight(.medium).monospacedDigit())
                .foregroundStyle(Token.textSecondary)
                .frame(width: rankColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.symbol.uppercased())
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Token.textPrimary)

                if let companyName, !companyName.isEmpty {
                    Text(companyName)
                        .font(.subheadline)
                        .foregroundStyle(Token.textSecondary)
                        .lineLimit(2)
                }

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
        VStack(alignment: .trailing, spacing: 4) {
            Text(percentileLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Token.primary)
                .multilineTextAlignment(.trailing)

            TrendChip(trend: rowTrend)
        }
    }

    private var rankColumnWidth: CGFloat {
        item.rank >= 10 ? 22 : 14
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Divider()
                .overlay(Token.gridLine)

            VStack(alignment: .leading, spacing: 6) {
                Text(percentileLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Token.textPrimary)

                if let signalStrength {
                    Text(signalStrength)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Token.primary)
                }

                if let detailTrend {
                    HStack(spacing: 6) {
                        Text("Price trend")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Token.textTertiary)
                        TrendChip(trend: detailTrend)
                    }
                }

                if inPortfolio {
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

            ScoreBreakdownView(segments: segments, isLoading: breakdownLoading)

            KeySignalsView(signals: signals, isLoading: breakdownLoading)

            if let insightHeadline {
                Text(insightHeadline)
                    .font(.subheadline)
                    .foregroundStyle(Token.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: onResearch) {
                    Label("Research", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(TopMoverActionStyle(primary: true))

                WatchlistToggleButton(
                    symbol: item.symbol,
                    companyName: companyName,
                    iconOnly: false
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct TrendChip: View {
    let trend: TrendDisplay

    var body: some View {
        HStack(spacing: 3) {
            Text(trend.glyph)
                .font(.caption.weight(.bold))
            Text(trend.label)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(trendColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trendColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var trendColor: Color {
        switch trend.tone {
        case .positive: AppColors.success
        case .negative: AppColors.error
        case .neutral: Token.textSecondary
        }
    }
}

private struct TopMoverActionStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: Layout.minTouchTarget)
            .background(
                primary
                    ? Token.primary.opacity(configuration.isPressed ? 0.75 : 1)
                    : Token.surfaceFillSecondary
            )
            .foregroundStyle(primary ? Token.onPrimary : Token.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
