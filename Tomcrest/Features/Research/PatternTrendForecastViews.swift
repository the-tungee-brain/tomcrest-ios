import SwiftUI

struct PatternTrendForecastCard: View {
    let forecast: PatternTrendForecastDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            if forecast.isBenchmark {
                PatternTrendBenchmarkNoticeCard(forecast: forecast)
            } else {
                PatternTrendMetricsCard(forecast: forecast)
            }

            if !forecast.inTrainingUniverse {
                AppInlineBanner(
                    message: outOfUniverseMessage,
                    tone: .neutral
                )
            }

            if !forecast.isBenchmark {
                PatternTrendProbabilityCard(forecast: forecast)
            }

            PatternTrendIndicatorsCard(
                indicators: forecast.resolvedIndicators,
                isBenchmark: forecast.isBenchmark
            )
            PatternTrendFootnote(forecast: forecast)
        }
    }

    private var outOfUniverseMessage: String {
        let universe = forecast.trainingUniverse?.uppercased() ?? "TOP20"
        return "This symbol is outside the model's trained universe (\(universe)). Treat the forecast as exploratory."
    }
}

private struct PatternTrendBenchmarkNoticeCard: View {
    let forecast: PatternTrendForecastDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Benchmark notice")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            Text(forecast.benchmarkNotice)
                .font(.subheadline)
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                PatternTrendMetaChip(
                    title: "As of",
                    value: formattedDate(forecast.asOfDate)
                )
                PatternTrendMetaChip(
                    title: "Horizon",
                    value: "\(forecast.horizonDays) sessions"
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.separator.opacity(0.35), lineWidth: 1)
                }
        )
    }

    private func formattedDate(_ raw: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct PatternTrendMetricsCard: View {
    let forecast: PatternTrendForecastDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Relative strength model")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            Text("This measures market-relative strength, not whether the stock must go up.")
                .font(.caption)
                .foregroundStyle(AppColors.tertiaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                if forecast.usesRankingPortfolio {
                    PatternTrendMetaChip(
                        title: "Ranking score",
                        value: formattedPercent(forecast.resolvedRankingScore)
                    )
                }
                PatternTrendMetaChip(
                    title: forecast.upProbChipLabel,
                    value: formattedPercent(forecast.upProb)
                )
                PatternTrendMetaChip(
                    title: "Relative strength class",
                    value: forecast.predictedClassLabel
                )
                PatternTrendMetaChip(
                    title: "Class probability",
                    value: formattedPercent(forecast.predictedClassProbability)
                )
                PatternTrendMetaChip(
                    title: "As of",
                    value: formattedDate(forecast.asOfDate)
                )
                PatternTrendMetaChip(
                    title: "Horizon",
                    value: "\(forecast.horizonDays) sessions"
                )
            }

            if let portfolioSummary = forecast.portfolioSummary {
                Text(portfolioSummary)
                    .font(.caption)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.separator.opacity(0.35), lineWidth: 1)
                }
        )
    }

    private func formattedPercent(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(0...1)))
    }

    private func formattedDate(_ raw: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct PatternTrendMetaChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.label)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct PatternTrendProbabilityCard: View {
    let forecast: PatternTrendForecastDisplay

    private var footnote: String {
        if forecast.labelScheme.isOutperformSpy {
            return "Outperform vs SPY · 5 sessions"
        }
        if forecast.labelScheme.isBinary {
            return "Binary class · 5 sessions"
        }
        return "Multi-class direction · 5 sessions"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppScreenSectionLabel(
                title: "Class probabilities",
                footnote: footnote
            )

            VStack(spacing: 12) {
                ForEach(Array(forecast.probabilityRows.enumerated()), id: \.offset) { _, row in
                    PatternTrendProbabilityRow(
                        label: row.label,
                        value: row.value,
                        accentColor: row.isSelected ? AppColors.accentHighlight : AppColors.secondaryLabel,
                        isSelected: row.isSelected
                    )
                }
            }
        }
        .appPanel(subtle: true)
    }
}

private struct PatternTrendProbabilityRow: View {
    let label: String
    let value: Double
    let accentColor: Color
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? accentColor : AppColors.label)
                Spacer()
                Text(value.formatted(.percent.precision(.fractionLength(0...1))))
                    .font(AppTypography.monoSubheadlineSemibold)
                    .foregroundStyle(isSelected ? accentColor : AppColors.secondaryLabel)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.insetSurface)
                    Capsule()
                        .fill(accentColor.opacity(isSelected ? 0.95 : 0.45))
                        .frame(width: max(6, proxy.size.width * value))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct PatternTrendIndicatorsCard: View {
    let indicators: [String: Double]
    let isBenchmark: Bool

    private var rows: [(title: String, key: String, format: PatternTrendIndicatorFormat)] {
        var base: [(title: String, key: String, format: PatternTrendIndicatorFormat)] = [
            ("Close vs SMA 20", "close_vs_sma20", .percent),
            ("Close vs SMA 200", "close_vs_sma200", .percent),
            ("Return (21d)", "ret_21d", .percent),
            ("Return (63d)", "ret_63d", .percent),
        ]
        if !isBenchmark {
            base.insert(("RS vs SPY (21d)", "rs_vs_spy_21d", .percent), at: 0)
            base.insert(("RS vs SPY (63d)", "rs_vs_spy_63d", .percent), at: 1)
            base.insert(("RS vs SPY (126d)", "rs_vs_spy_126d", .percent), at: 2)
        }
        return base
    }

    var body: some View {
        let visibleRows = rows.filter { indicators[$0.key] != nil }
        if visibleRows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                AppScreenSectionLabel(
                    title: isBenchmark ? "Trend & regime" : "Relative strength evidence"
                )

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(visibleRows, id: \.key) { row in
                        PatternTrendIndicatorTile(
                            title: row.title,
                            value: row.format.string(for: indicators[row.key] ?? 0)
                        )
                    }
                }
            }
            .appPanel(subtle: true)
        }
    }
}

private enum PatternTrendIndicatorFormat {
    case decimal(Int)
    case price
    case percent

    func string(for value: Double) -> String {
        switch self {
        case let .decimal(fractionLength):
            return value.formatted(.number.precision(.fractionLength(fractionLength)))
        case .price:
            if abs(value) >= 1000 {
                return value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
            }
            return value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
        case .percent:
            return value.formatted(.percent.precision(.fractionLength(0...1)))
        }
    }
}

private struct PatternTrendIndicatorTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            Text(value)
                .font(AppTypography.monoCardTitle)
                .foregroundStyle(AppColors.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PatternTrendFootnote: View {
    let forecast: PatternTrendForecastDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trainEndDate = forecast.modelTrainEndDate, !forecast.isBenchmark {
                Text("Model trained through \(trainEndDate).")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Text(
                forecast.isBenchmark
                    ? "Not investment advice. Quantitative regime inputs only — relative-strength ranking does not apply to the benchmark."
                    : "Not investment advice. Market-relative model evidence only — see Price Structure Evidence for the chart read."
            )
            .font(.caption)
            .foregroundStyle(AppColors.tertiaryLabel)
            .lineSpacing(2)
        }
        .padding(.horizontal, 4)
    }
}
