import SwiftUI

struct SymbolPatternPredictionTab: View {
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        ResearchDepthTabShell(tab: .trend, viewModel: viewModel) {
            if let prediction = viewModel.patternPrediction {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    TrendPredictionHeroCard(
                        prediction: prediction,
                        modelMeta: viewModel.patternModelHealth?.model
                    )
                    TrendProbabilityCard(prediction: prediction)
                    TrendIndicatorsCard(indicators: prediction.indicators)
                    TrendModelFootnote(modelMeta: viewModel.patternModelHealth?.model)
                }
            }
        }
    }
}

// MARK: - Hero

private struct TrendPredictionHeroCard: View {
    let prediction: PatternPredictionResponse
    let modelMeta: PatternPredictionModelMeta?

    private var signal: TrendSignal { prediction.signal }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(signal.accentColor.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: signal.systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(signal.accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(signal.title)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.label)

                    Text("Next 5 trading days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .textCase(.uppercase)

                    Text(signal.subtitle)
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                TrendMetaChip(title: "As of", value: formattedDate(prediction.date))
                if let confidence = topProbability {
                    TrendMetaChip(title: "Confidence", value: confidence)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(signal.accentColor.opacity(0.22), lineWidth: 1)
                }
        )
    }

    private var topProbability: String? {
        let value = prediction.probability(for: signal)
        guard value > 0 else { return nil }
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

private struct TrendMetaChip: View {
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

// MARK: - Probabilities

private struct TrendProbabilityCard: View {
    let prediction: PatternPredictionResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppScreenSectionLabel(
                title: "Class probabilities",
                footnote: "Model estimate for the 5-day direction bucket"
            )

            VStack(spacing: 12) {
                ForEach(TrendSignal.allCases, id: \.rawValue) { signal in
                    TrendProbabilityRow(
                        signal: signal,
                        value: prediction.probability(for: signal),
                        isSelected: prediction.signal == signal
                    )
                }
            }
        }
        .padding(16)
        .appPanel(subtle: true)
    }
}

private struct TrendProbabilityRow: View {
    let signal: TrendSignal
    let value: Double
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(signal.probabilityLabel, systemImage: signal.systemImage)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? signal.accentColor : AppColors.label)
                Spacer()
                Text(value.formatted(.percent.precision(.fractionLength(0...1))))
                    .font(AppTypography.monoSubheadlineSemibold)
                    .foregroundStyle(isSelected ? signal.accentColor : AppColors.secondaryLabel)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.insetSurface)
                    Capsule()
                        .fill(signal.accentColor.opacity(isSelected ? 0.95 : 0.45))
                        .frame(width: max(6, proxy.size.width * value))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Indicators

private struct TrendIndicatorsCard: View {
    let indicators: [String: Double]

    private var rows: [(title: String, key: String, format: TrendIndicatorFormat)] {
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
                ForEach(rows, id: \.key) { row in
                    TrendIndicatorTile(
                        title: row.title,
                        value: formattedValue(for: row.key, format: row.format)
                    )
                }
            }
        }
        .padding(16)
        .appPanel(subtle: true)
    }

    private func formattedValue(for key: String, format: TrendIndicatorFormat) -> String {
        guard let value = indicators[key] else { return "—" }
        return format.string(for: value)
    }
}

private enum TrendIndicatorFormat {
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

private struct TrendIndicatorTile: View {
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

// MARK: - Footnote

private struct TrendModelFootnote: View {
    let modelMeta: PatternPredictionModelMeta?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trainEnd = modelMeta?.trainEndDate {
                Text("Model trained through \(trainEnd)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Text(
                "This signal is generated from daily price, indicator, and candlestick features for stocks and ETFs. It describes a modeled 5-day direction bucket, not a trade recommendation."
            )
            .font(.caption)
            .foregroundStyle(AppColors.tertiaryLabel)
            .lineSpacing(2)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Signal styling

private extension TrendSignal {
    var accentColor: Color {
        switch self {
        case .bearish: AppColors.error
        case .neutral: AppColors.warning
        case .bullish: AppColors.success
        }
    }

    var systemImage: String {
        switch self {
        case .bearish: "arrow.down.right.circle.fill"
        case .neutral: "minus.circle.fill"
        case .bullish: "arrow.up.right.circle.fill"
        }
    }
}

#if DEBUG
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            TrendPredictionHeroCard(
                prediction: PatternPredictionResponse(
                    symbol: "AAPL",
                    date: "2024-12-31",
                    prediction: 1,
                    probabilities: ["-1": 0.12, "0": 0.23, "1": 0.65],
                    indicators: [
                        "rsi_14": 58.4,
                        "sma_20": 191.2,
                        "sma_200": 178.6,
                        "macd": 1.842,
                        "bb_pct": 0.71,
                    ]
                ),
                modelMeta: PatternPredictionModelMeta(
                    trainEndDate: "2024-12-31",
                    trainStartDate: "2019-01-01",
                    nFeatures: 28,
                    symbols: ["AAPL"]
                )
            )
        }
        .padding()
    }
    .background(AppColors.background)
}
#endif
