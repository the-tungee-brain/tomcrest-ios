import SwiftUI

enum AppTab: Hashable {
    case portfolio
    case research
    case settings
}

struct MainTabView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AccountContext.self) private var account
    @State private var selectedTab: AppTab = .portfolio

    var body: some View {
        TabView(selection: $selectedTab) {
            PortfolioView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie")
                }
                .tag(AppTab.portfolio)

            ResearchView()
                .tabItem {
                    Label("Research", systemImage: "magnifyingglass")
                }
                .tag(AppTab.research)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .appMainTabBarChrome()
        .background(AppColors.background)
        .task(id: auth.accessToken) {
            guard let accessToken = auth.accessToken else { return }
            await account.loadPlan(accessToken: accessToken)
        }
    }
}

#Preview {
    AppPreview.environments {
        MainTabView()
            .environment(AuthSession())
            .environment(AccountContext())
    }
}
