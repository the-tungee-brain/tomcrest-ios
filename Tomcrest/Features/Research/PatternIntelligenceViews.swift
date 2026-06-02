import SwiftUI

struct PatternIntelligenceCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            PatternIntelligencePatternHeaderCard(intelligence: intelligence)
            if let signalState = intelligence.interpretation?.signalState {
                PatternIntelligenceSignalStateCard(
                    signalState: signalState,
                    toneColor: intelligence.verdictColor,
                    isBenchmark: intelligence.isBenchmark,
                    benchmarkNotice: intelligence.benchmarkNotice
                )
            }
            if let timeframe = intelligence.interpretation?.timeframe {
                PatternIntelligenceTimeframeCard(
                    timeframe: timeframe,
                    isBenchmark: intelligence.isBenchmark
                )
            }
            PatternIntelligenceVerdictCard(intelligence: intelligence)
            if let alignment = intelligence.interpretation?.alignment {
                PatternIntelligenceConflictCard(alignment: alignment)
            }
            PatternIntelligenceRawSignalsCard(intelligence: intelligence)
            PatternIntelligenceEvidenceCard(intelligence: intelligence)
            PatternIntelligenceDisclaimer(text: intelligence.explanation.disclaimer)
        }
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
                    .font(.title3)
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

private struct PatternIntelligencePatternHeaderCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pattern")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            if let pattern = intelligence.primaryPattern {
                HStack(alignment: .center, spacing: 8) {
                    Text(pattern.label)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    PatternHelpButton(patternId: pattern.patternId)
                }
                Text(patternSubtitle(pattern))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
            } else {
                Text("No active pattern")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text("Trend and model context still apply.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }

    private func patternSubtitle(_ pattern: PrimaryCandlestickPattern) -> String {
        let direction: String
        switch pattern.direction.lowercased() {
        case "bullish": direction = "Bullish"
        case "bearish": direction = "Bearish"
        default: direction = "Neutral"
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
}

private struct PatternIntelligenceSignalStateCard: View {
    let signalState: PatternSignalState
    let toneColor: Color
    let isBenchmark: Bool
    let benchmarkNotice: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isBenchmark ? "Benchmark notice" : "Signal state")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            if isBenchmark {
                Text(signalState.benchmarkNotice ?? benchmarkNotice)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(signalState.label)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(toneColor)
                Text(signalState.probabilityText)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
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
}

private struct PatternIntelligenceTimeframeCard: View {
    let timeframe: PatternTimeframeInterpretation
    let isBenchmark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Multi-timeframe read")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                timeframeTile(
                    title: "Short-term outlook",
                    slice: timeframe.shortTerm
                )
                timeframeTile(
                    title: "Long-term trend",
                    slice: timeframe.longTermTrend
                )
                timeframeTile(
                    title: isBenchmark ? "Market regime" : "Relative strength",
                    slice: timeframe.relativeStrength
                )
            }
        }
        .appPanel(subtle: true)
    }

    private func timeframeTile(title: String, slice: PatternTimeframeSlice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)
            Text(slice.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
            Text(slice.caption)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.secondaryBackground.opacity(0.5))
        )
    }
}

private struct PatternIntelligenceRawSignalsCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        let summary = intelligence.interpretation?.signalSummary

        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                if let summary {
                    if !intelligence.isBenchmark {
                        signalRow(label: "Model C", value: summary.modelC, emphasize: true)
                    }
                    signalRow(label: "Trend", value: summary.trend)
                    if !intelligence.isBenchmark {
                        signalRow(label: "Relative strength", value: summary.relativeStrength)
                    }
                    if let pattern = summary.pattern {
                        signalRow(
                            label: "Pattern",
                            value: pattern,
                            warn: summary.patternWarning == true
                        )
                    }
                } else if !intelligence.isBenchmark {
                    signalRow(label: "Model C", value: intelligence.explanation.modelContext)
                }

                Text("As of \(formattedDate(intelligence.asOfDate))")
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
            .padding(.top, 8)
        } label: {
            Text("Raw signals")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)
        }
        .appPanel(subtle: true)
    }

    private func signalRow(
        label: String,
        value: String,
        warn: Bool = false,
        emphasize: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(emphasize ? .caption.weight(.bold) : .caption.weight(.semibold))
                .foregroundStyle(warn ? AppColors.warning : AppColors.label)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct PatternIntelligenceVerdictCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verdict")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)
            Text(intelligence.verdict)
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(intelligence.verdictColor.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(intelligence.verdictColor.opacity(0.2), lineWidth: 1)
                }
        )
    }
}

private struct PatternIntelligenceConflictCard: View {
    let alignment: PatternAlignmentBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(alignment.headline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.warning)
                .textCase(.uppercase)
            Text(alignment.explanation)
                .font(.subheadline)
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.warning.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.warning.opacity(0.25), lineWidth: 1)
                }
        )
    }
}

private struct PatternIntelligenceEvidenceCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        if let evidence = intelligence.interpretation?.evidence {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(evidence.displayFraming)
                            .font(AppTypography.body.weight(.semibold))
                            .foregroundStyle(AppColors.label)
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = evidence.statsNote {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(AppColors.tertiaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let note = evidence.conditionalNote {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(AppColors.tertiaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if evidence.hasStats {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                            ],
                            spacing: 8
                        ) {
                            PatternTrendMetaChip(
                                title: "Occurrences",
                                value: "\(evidence.occurrenceCount ?? 0)"
                            )
                            PatternTrendMetaChip(
                                title: "5d win rate",
                                value: formattedPercent(evidence.winRate5d)
                            )
                            PatternTrendMetaChip(
                                title: "Avg 5d",
                                value: formattedPercent(evidence.avgReturn5d)
                            )
                            PatternTrendMetaChip(
                                title: "Avg 20d",
                                value: formattedPercent(evidence.avgReturn20d)
                            )
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Historical evidence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .textCase(.uppercase)
            }
            .appPanel(subtle: true)
        }
    }

    private func formattedPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value * 100)
    }
}

private struct PatternIntelligenceDisclaimer: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(AppColors.tertiaryLabel)
            .fixedSize(horizontal: false, vertical: true)
    }
}
