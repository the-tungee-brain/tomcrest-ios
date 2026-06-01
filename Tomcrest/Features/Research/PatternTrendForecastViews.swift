import SwiftUI

struct PatternTrendForecastCard: View {
    let forecast: PatternTrendForecastDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            PatternTrendHeroCard(forecast: forecast)

            if !forecast.inTrainingUniverse {
                AppInlineBanner(
                    message: "This symbol is outside the model's trained universe. Treat the forecast as exploratory.",
                    tone: .neutral
                )
            }

            PatternTrendProbabilityCard(forecast: forecast)
            PatternTrendIndicatorsCard(indicators: forecast.indicators)
            PatternTrendFootnote(trainEndDate: forecast.modelTrainEndDate)
        }
    }
}

private struct PatternTrendHeroCard: View {
    let forecast: PatternTrendForecastDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(forecast.accentColor.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: forecast.systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(forecast.accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(forecast.directionTitle)
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(AppColors.label)

                        if let tradeLabel = forecast.tradeSignalLabel {
                            Text(tradeLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(forecast.tradeSignalColor)
                                .textCase(.uppercase)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(forecast.tradeSignalColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text("Next 5 trading days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .textCase(.uppercase)

                    Text(forecast.directionSubtitle)
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                PatternTrendMetaChip(
                    title: "P(up)",
                    value: formattedPercent(forecast.upProb)
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
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(forecast.accentColor.opacity(0.22), lineWidth: 1)
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

private struct PatternTrendMetaChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.label)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct PatternTrendProbabilityCard: View {
    let forecast: PatternTrendForecastDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppScreenSectionLabel(
                title: "Class probabilities",
                footnote: forecast.labelScheme.isBinary
                    ? "Binary up/down estimate for the next 5 sessions"
                    : "Model estimate for the 5-day direction bucket"
            )

            VStack(spacing: 12) {
                ForEach(Array(forecast.probabilityRows.enumerated()), id: \.offset) { _, row in
                    PatternTrendProbabilityRow(
                        label: row.label,
                        value: row.value,
                        accentColor: row.isSelected ? forecast.accentColor : AppColors.secondaryLabel,
                        isSelected: row.isSelected
                    )
                }
            }
        }
        .padding(16)
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

    private var rows: [(title: String, key: String, format: PatternTrendIndicatorFormat)] {
        [
            ("RSI (14)", "rsi_14", .decimal(1)),
            ("SMA 20", "sma_20", .price),
            ("SMA 200", "sma_200", .price),
            ("MACD", "macd", .decimal(3)),
            ("Bollinger %B", "bb_pct", .percent),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppScreenSectionLabel(
                title: "Technical snapshot",
                footnote: "Features used for this prediction"
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(rows.filter { indicators[$0.key] != nil }, id: \.key) { row in
                    PatternTrendIndicatorTile(
                        title: row.title,
                        value: row.format.string(for: indicators[row.key] ?? 0)
                    )
                }
            }
        }
        .padding(16)
        .appPanel(subtle: true)
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
        .padding(12)
        .background(AppColors.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PatternTrendFootnote: View {
    let trainEndDate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trainEndDate {
                Text("Model trained through \(trainEndDate).")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Text("Not investment advice. This describes a modeled 5-day direction estimate, not a trade recommendation.")
                .font(.caption)
                .foregroundStyle(AppColors.tertiaryLabel)
                .lineSpacing(2)
        }
        .padding(.horizontal, 4)
    }
}
