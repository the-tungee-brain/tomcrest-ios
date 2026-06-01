import SwiftUI

struct WatchlistHint: View {
    @Environment(WatchlistStore.self) private var watchlistStore
    let symbol: String

    @State private var dismissed = OnboardingStorage.isWatchlistHintDismissed()

    private var upper: String { symbol.uppercased() }

    var body: some View {
        if !dismissed, !watchlistStore.contains(symbol) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "star")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tap the star to save \(upper) to your watchlist for quick access from Research.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(2)

                    Button("Dismiss") {
                        OnboardingStorage.dismissWatchlistHint()
                        dismissed = true
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.accentMuted.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.panelBorder, lineWidth: 1)
            }
        }
    }
}
