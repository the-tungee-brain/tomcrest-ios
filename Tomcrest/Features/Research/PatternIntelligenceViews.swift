import SwiftUI

struct PatternIntelligenceCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            PatternIntelligenceHeroCard(intelligence: intelligence)
            PatternIntelligenceTraderSummaryCard(intelligence: intelligence)
            PatternIntelligenceFinalVerdictCard(intelligence: intelligence)
            PatternIntelligenceContributorsCard(intelligence: intelligence)
            PatternIntelligenceContextCard(intelligence: intelligence)
            PatternIntelligenceSetupHistoryCard(intelligence: intelligence)
            PatternIntelligenceDisclaimer(text: intelligence.explanation.disclaimer)
        }
    }
}

private struct PatternIntelligenceHeroCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(intelligence.heroColor.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: intelligence.heroSystemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(intelligence.heroColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(intelligence.actionableVerdict)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.label)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(intelligence.explanation.headline)
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                PatternTrendMetaChip(title: "Core signal", value: "Model C")
                PatternTrendMetaChip(
                    title: "Trend",
                    value: intelligence.trendContext.trendBias.capitalized
                )
                PatternTrendMetaChip(title: "Pattern role", value: "10% weight")
                PatternTrendMetaChip(
                    title: "As of",
                    value: formattedDate(intelligence.asOfDate)
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(intelligence.heroColor.opacity(0.22), lineWidth: 1)
                }
        )
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct PatternIntelligenceTraderSummaryCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trader summary")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .textCase(.uppercase)
            Text(intelligence.traderSummary)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.accentHighlight.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.accentHighlight.opacity(0.18), lineWidth: 1)
                }
        )
    }
}

private struct PatternIntelligenceFinalVerdictCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        if let verdict = intelligence.interpretation?.finalVerdict {
            VStack(alignment: .leading, spacing: 12) {
                Text(verdict.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(verdict.bullets) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text(intelligence.verdictBulletSymbol(bullet.tone))
                                .font(.caption)
                            Text(bullet.text)
                                .font(AppTypography.bodySecondary)
                                .foregroundStyle(AppColors.label)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Divider()

                Text("Conclusion")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .textCase(.uppercase)
                Text(verdict.conclusion)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .appPanel(subtle: true)
        }
    }
}

private struct PatternIntelligenceContributorsCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        if let contributors = intelligence.interpretation?.confidenceContributors, !contributors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Confidence contributors")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .textCase(.uppercase)

                Text(
                    "Trend and relative strength drive 70% of the confirmation score. Pattern strength is capped at 10%."
                )
                .font(.caption)
                .foregroundStyle(AppColors.tertiaryLabel)
                .fixedSize(horizontal: false, vertical: true)

                ForEach(contributors) { row in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(row.label) (\(row.weightPct)% weight)")
                                .font(.caption.weight(row.emphasized ? .semibold : .regular))
                                .foregroundStyle(row.emphasized ? AppColors.label : AppColors.secondaryLabel)
                            if row.emphasized {
                                Text("Core contributor")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppColors.accentHighlight)
                                    .textCase(.uppercase)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(row.qualitative)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.label)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                row.emphasized
                                    ? AppColors.accentHighlight.opacity(0.08)
                                    : AppColors.insetSurface.opacity(0.55)
                            )
                    )
                }
            }
            .padding(16)
            .appPanel(subtle: true)
        }
    }
}

private struct PatternIntelligenceContextCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(intelligence.explanation.modelContext)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
            Text(intelligence.explanation.trendContext)
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .appPanel(subtle: true)
    }
}

private struct PatternIntelligenceSetupHistoryCard: View {
    let intelligence: PatternIntelligenceDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup history (pattern + trend + RS)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            if let setup = intelligence.setupOutcome {
                Text(setup.label)
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)

                if setup.hasStats {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                        ],
                        spacing: 8
                    ) {
                        PatternTrendMetaChip(title: "Occurrences", value: "\(setup.occurrenceCount)")
                        PatternTrendMetaChip(title: "Avg 5d", value: formattedPercent(setup.avgReturn5d))
                        PatternTrendMetaChip(title: "Avg 20d", value: formattedPercent(setup.avgReturn20d))
                        PatternTrendMetaChip(title: "5d win rate", value: formattedPercent(setup.winRate5d))
                    }
                } else {
                    Text(intelligence.historicalRead ?? intelligence.explanation.historicalContext)
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let historicalRead = intelligence.interpretation?.historicalRead {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Historical read")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                        .textCase(.uppercase)
                    Text(historicalRead)
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .appPanel(subtle: true)
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
            .font(.caption)
            .foregroundStyle(AppColors.tertiaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.insetSurface.opacity(0.6))
            )
    }
}
