import SwiftUI

struct WatchlistSymbolRow: View {
    @Environment(WatchlistStore.self) private var watchlistStore

    let symbol: WatchlistSymbol
    var style: WatchlistSymbolRowStyle = .card
    var isDragging = false
    var onTap: (() -> Void)?

    private var quote: WatchlistQuote {
        watchlistStore.quoteStore.quote(for: symbol.id)
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol.ticker)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.label)
                    Text(symbol.companyName)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(CurrencyFormatter.usd(quote.price))
                        .font(AppTypography.monoCaptionSemibold)
                        .foregroundStyle(AppColors.label)

                    HStack(spacing: 4) {
                        WatchlistTrendGlyph(change: quote.dayChangePercent)

                        Text(CurrencyFormatter.percent(quote.dayChangePercent))
                            .font(AppTypography.monoCaption2)
                            .foregroundStyle(WatchlistProfitTone.color(for: quote.dayChangePercent))
                    }
                }
            }
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(style.backgroundColor(isDragging: isDragging))
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .overlay {
                if style.showsBorder {
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .strokeBorder(AppColors.separator.opacity(0.6), lineWidth: 1)
                }
            }
            .opacity(isDragging ? 0.65 : 1)
            .scaleEffect(isDragging ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

enum WatchlistSymbolRowStyle {
    case card
    case plain

    var horizontalPadding: CGFloat {
        switch self {
        case .card: 14
        case .plain: 14
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .card: 11
        case .plain: 12
        }
    }

    var showsBorder: Bool {
        switch self {
        case .card: true
        case .plain: false
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .card: 12
        case .plain: 0
        }
    }

    func backgroundColor(isDragging: Bool) -> Color {
        switch self {
        case .card:
            AppColors.background.opacity(isDragging ? 0.55 : 0.35)
        case .plain:
            .clear
        }
    }
}

struct WatchlistFolderDayChangeView: View {
    @Environment(WatchlistStore.self) private var watchlistStore

    let folder: WatchlistFolder

    var body: some View {
        if !folder.symbols.isEmpty {
            WatchlistFolderPerformanceSummary(change: totals.value, percent: totals.percent)
        }
    }

    private var totals: (value: Double, percent: Double) {
        let quotes = folder.symbols.map { watchlistStore.quoteStore.quote(for: $0.id) }
        let total = quotes.reduce(0) { $0 + $1.dayChange }
        let averagePercent = quotes.reduce(0) { $0 + $1.dayChangePercent } / Double(quotes.count)
        return (total, averagePercent)
    }
}

struct WatchlistTrendGlyph: View {
    let change: Double

    var body: some View {
        Image(systemName: glyphName)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(WatchlistProfitTone.color(for: change))
            .frame(width: 14, height: 14)
            .background(WatchlistProfitTone.color(for: change).opacity(0.12))
            .clipShape(Circle())
    }

    private var glyphName: String {
        if change > 0.05 { return "arrow.up.right" }
        if change < -0.05 { return "arrow.down.right" }
        return "minus"
    }
}

struct WatchlistFolderPerformanceSummary: View {
    let change: Double
    let percent: Double

    var body: some View {
        HStack(spacing: 6) {
            WatchlistTrendGlyph(change: percent)
                .layoutPriority(1)

            (
                Text(CurrencyFormatter.signedUsd(change))
                    .font(AppTypography.monoCaption2Semibold)
                    .foregroundStyle(WatchlistProfitTone.color(for: change))
                + Text(" · ")
                    .font(AppTypography.monoCaption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
                + Text(CurrencyFormatter.percent(percent))
                    .font(AppTypography.monoCaption2)
                    .foregroundStyle(WatchlistProfitTone.color(for: percent))
            )
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.85)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}
