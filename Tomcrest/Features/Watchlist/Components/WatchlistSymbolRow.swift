import SwiftUI

struct WatchlistSymbolRow: View {
    let symbol: WatchlistSymbol
    var folderAccent: Color = AppColors.accentHighlight
    var showsDragHandle = false
    var isDragging = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                if showsDragHandle {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .frame(width: 16)
                }

                SymbolAvatar(symbol: symbol.ticker, size: 36, accent: folderAccent)

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
                    Text(CurrencyFormatter.usd(symbol.price))
                        .font(AppTypography.monoCaptionSemibold)
                        .foregroundStyle(AppColors.label)

                    HStack(spacing: 4) {
                        WatchlistTrendGlyph(change: symbol.dayChangePercent)

                        Text(CurrencyFormatter.percent(symbol.dayChangePercent))
                            .font(AppTypography.monoCaption2)
                            .foregroundStyle(WatchlistProfitTone.color(for: symbol.dayChangePercent))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(AppColors.background.opacity(isDragging ? 0.55 : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppColors.separator.opacity(0.6), lineWidth: 1)
            }
            .opacity(isDragging ? 0.65 : 1)
            .scaleEffect(isDragging ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
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
            Text(CurrencyFormatter.signedUsd(change))
                .font(AppTypography.monoCaption2Semibold)
                .foregroundStyle(WatchlistProfitTone.color(for: change))
            Text("·")
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(CurrencyFormatter.percent(percent))
                .font(AppTypography.monoCaption2)
                .foregroundStyle(WatchlistProfitTone.color(for: percent))
        }
    }
}
