import SwiftUI

struct PatternIntelligenceCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            PatternIntelligenceSignalSummaryCard(intelligence: intelligence)
            PatternIntelligenceVerdictCard(intelligence: intelligence)
            PatternIntelligenceEvidenceCard(intelligence: intelligence)
            PatternIntelligenceDisclaimer(text: intelligence.explanation.disclaimer)
        }
    }
}

private struct PatternIntelligenceSignalSummaryCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        let summary = intelligence.interpretation?.signalSummary

        VStack(alignment: .leading, spacing: 10) {
            Text("Signal summary")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            if let summary {
                signalRow(label: "Model C", value: summary.modelC)
                signalRow(label: "Trend", value: summary.trend)
                signalRow(label: "Relative strength", value: summary.relativeStrength)
                if let pattern = summary.pattern {
                    signalRow(
                        label: "Pattern",
                        value: pattern,
                        warn: summary.patternWarning == true
                    )
                }
            } else {
                signalRow(label: "Model C", value: intelligence.explanation.modelContext)
            }

            Text("As of \(formattedDate(intelligence.asOfDate))")
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .appPanel(subtle: true)
    }

    private func signalRow(label: String, value: String, warn: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(.caption.weight(.semibold))
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

private struct PatternIntelligenceEvidenceCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        if let evidence = intelligence.interpretation?.evidence {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Insight")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryLabel)
                            .textCase(.uppercase)
                        Text(evidence.insight)
                            .font(AppTypography.body.weight(.semibold))
                            .foregroundStyle(AppColors.label)
                            .fixedSize(horizontal: false, vertical: true)
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
                Text("Evidence")
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
