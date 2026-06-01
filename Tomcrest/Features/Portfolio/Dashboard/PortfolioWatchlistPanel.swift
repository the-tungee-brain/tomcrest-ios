import SwiftUI

struct PortfolioWatchlistPanel: View {
    @Environment(WatchlistStore.self) private var watchlistStore
    let onSelect: (String) -> Void

    @State private var isExpanded = !OnboardingStorage.isPortfolioWatchlistCollapsed()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                    OnboardingStorage.setPortfolioWatchlistCollapsed(!isExpanded)
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Watchlist")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)

                    if watchlistStore.hasSymbols {
                        Text("\(watchlistStore.allTickers.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryLabel)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    if watchlistStore.allTickers.isEmpty {
                        PortfolioQuickLinkRow(
                            icon: "star",
                            iconTint: AppColors.secondaryLabel,
                            title: "No saved symbols",
                            subtitle: "Star tickers in Research to track them here"
                        )
                        .allowsHitTesting(false)
                    } else {
                        ForEach(Array(watchlistStore.allTickers.enumerated()), id: \.element) { index, symbol in
                            Button {
                                onSelect(symbol)
                            } label: {
                                PortfolioQuickLinkRow(
                                    icon: "star.fill",
                                    title: symbol,
                                    subtitle: "Open research"
                                )
                            }
                            .buttonStyle(.plain)

                            if index < watchlistStore.allTickers.count - 1 {
                                Divider().overlay(AppColors.separator).padding(.leading, 58)
                            }
                        }
                    }
                }
                .background(AppColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.panelBorder, lineWidth: 1)
                }
            }
        }
    }
}
