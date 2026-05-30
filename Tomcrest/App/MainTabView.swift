import SwiftUI

enum AppTab: Hashable {
    case portfolio
    case research
    case settings
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .portfolio

    var body: some View {
        TabView(selection: $selectedTab) {
            PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie.fill")
                }
                .tag(AppTab.portfolio)

            ResearchView()
                .tabItem {
                    Label("Research", systemImage: "magnifyingglass")
                }
                .tag(AppTab.research)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
    }
}

#Preview {
    MainTabView()
        .environment(AuthSession())
}
