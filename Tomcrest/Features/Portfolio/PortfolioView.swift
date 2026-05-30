import SwiftUI

struct PortfolioView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    placeholderCard(
                        title: "Morning brief",
                        subtitle: "Phase 3 — connect Schwab, then load `/portfolio/morning-brief`.",
                        symbol: "sun.max.fill"
                    )

                    placeholderCard(
                        title: "Alerts",
                        subtitle: "Actionable items from `/get-account-positions`.",
                        symbol: "bell.badge.fill"
                    )

                    placeholderCard(
                        title: "AI chat",
                        subtitle: "Phase 4 — streaming portfolio assistant.",
                        symbol: "bubble.left.and.text.bubble.right.fill"
                    )
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.title2.bold())
                .foregroundStyle(Theme.foreground)
            Text("Your Schwab holdings, brief, and alerts.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    private func placeholderCard(title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel()
    }
}

#Preview {
    PortfolioView()
        .environment(AuthSession())
}
