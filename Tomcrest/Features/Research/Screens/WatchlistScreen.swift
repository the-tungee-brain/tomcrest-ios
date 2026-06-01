import SwiftUI

struct WatchlistScreen: View {
    @Environment(ResearchSymbolBookmarks.self) private var bookmarks
    let onSelect: (String) -> Void

    var body: some View {
        AppScrollScreen {
            if bookmarks.watchlist.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Save symbols from Research search or symbol pages to track them here.")
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(3)

                    Text("Tap the star on any search result or research page.")
                        .font(.caption)
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .appPanel(subtle: true)
            } else {
                AppGroupedList {
                    ForEach(Array(bookmarks.watchlist.enumerated()), id: \.element) { index, symbol in
                        HStack(spacing: 0) {
                            Button {
                                onSelect(symbol)
                            } label: {
                                SavedWatchlistSymbolRow(symbol: symbol)
                            }
                            .buttonStyle(.plain)

                            Button {
                                bookmarks.removeFromWatchlist(symbol)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.secondaryLabel)
                                    .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(symbol) from watchlist")
                        }

                        if index < bookmarks.watchlist.count - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
        .navigationTitle("Watchlist")
        .navigationBarTitleDisplayMode(.large)
        .appPushedScreenCanvas()
    }
}

private struct SavedWatchlistSymbolRow: View {
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                Text("Saved for research")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
    }
}
