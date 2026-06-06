import SwiftUI

struct PatternIntelligenceCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        if let summary = intelligence.analystSummary {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                ChartAnalystSummaryPanel(
                    summary: summary,
                    pattern: intelligence.primaryPattern,
                    isBenchmark: intelligence.isBenchmark,
                    benchmarkNotice: intelligence.benchmarkNotice,
                    toneColor: intelligence.verdictColor,
                    asOfDate: intelligence.asOfDate
                )
            }
        }
    }
}

struct ChartAnalystSummaryPanel: View {
    let summary: ChartAnalystSummary
    let pattern: PrimaryCandlestickPattern?
    let isBenchmark: Bool
    let benchmarkNotice: String
    let toneColor: Color
    let asOfDate: String

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            outlookSection
            keyLevelSection
            if !summary.whyThisOutlook.isEmpty {
                whySection
            }
            thesisSection
            Text(summary.disclaimer)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            Text("As of \(formattedDate(asOfDate))")
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
        }
    }

    private var outlookSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Outlook")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            Text("Chart structure: \(summary.outlook.headline)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(isBenchmark ? AppColors.label : toneColor)

            Text(summary.outlook.expectation)
                .font(.subheadline)
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)

            if isBenchmark {
                Text(summary.outlook.benchmarkNotice ?? benchmarkNotice)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let pattern {
                compactPatternLine(pattern)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isBenchmark ? AppColors.secondaryBackground.opacity(0.5) : toneColor.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isBenchmark ? AppColors.separator.opacity(0.35) : toneColor.opacity(0.2),
                            lineWidth: 1
                        )
                }
        )
    }

    @ViewBuilder
    private var keyLevelSection: some View {
        if summary.keyLevel.isActionable {
            VStack(alignment: .leading, spacing: 8) {
                Text("Key level")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .textCase(.uppercase)
                Text(summary.keyLevel.display)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(summary.keyLevel.implication)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .appPanel(subtle: true)
        }
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why this chart read")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(summary.whyThisOutlook.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Text(bullet.tone == "caution" ? "⚠" : "✓")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                bullet.tone == "caution" ? AppColors.warning : AppColors.success
                            )
                        Text(bullet.text)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .appPanel(subtle: true)
    }

    private var thesisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Structure thesis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)
            Text(summary.thesis)
                .font(.subheadline)
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appPanel(subtle: true)
    }

    @ViewBuilder
    private func compactPatternLine(_ pattern: PrimaryCandlestickPattern) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text("\(pattern.label) · \(patternSubtitle(pattern))")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            PatternHelpButton(patternId: pattern.patternId)
        }
        .padding(.top, 4)
    }

    private func patternSubtitle(_ pattern: PrimaryCandlestickPattern) -> String {
        let direction: String
        switch pattern.direction.lowercased() {
        case "bullish": direction = "Chart structure: Bullish"
        case "bearish": direction = "Chart structure: Bearish"
        default: direction = "Chart structure: Neutral"
        }

        let quality: String
        if pattern.strength >= 0.7 {
            quality = "High quality"
        } else if pattern.strength >= 0.45 {
            quality = "Moderate weight"
        } else {
            quality = "Low weight"
        }

        return "\(direction) · \(quality)"
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct PatternHelpButton: View {
    let patternId: String
    @State private var showHelp = false

    var body: some View {
        if let description = PatternCandlestickReference.description(for: patternId) {
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("What is this candlestick pattern?")
            .popover(isPresented: $showHelp, arrowEdge: .top) {
                PatternHelpPopoverContent(description: description)
            }
        }
    }
}

private struct PatternHelpPopoverContent: View {
    let description: String

    var body: some View {
        ScrollView {
            Text(description)
                .font(.subheadline)
                .foregroundStyle(AppColors.label)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 300)
        .frame(maxHeight: 260)
        .padding(16)
        .presentationCompactAdaptation(.popover)
    }
}
