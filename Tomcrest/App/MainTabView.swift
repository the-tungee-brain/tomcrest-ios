import SwiftUI

enum AppTab: Hashable {
    case portfolio
    case movers
    case research
    case settings
}

struct MainTabView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AccountContext.self) private var account
    @State private var selectedTab: AppTab = .portfolio
    @State private var settingsFocus: SettingsFocus?

    var body: some View {
        TabView(selection: $selectedTab) {
            PortfolioView(selectedTab: $selectedTab, settingsFocus: $settingsFocus)
                .tabItem {
                    Label("Portfolio", systemImage: selectedTab == .portfolio ? "chart.pie.fill" : "chart.pie")
                }
                .tag(AppTab.portfolio)

            TopMoversView()
                .tabItem {
                    Label("Movers", systemImage: selectedTab == .movers ? "arrow.up.right.circle.fill" : "arrow.up.right.circle")
                }
                .tag(AppTab.movers)

            ResearchView()
                .tabItem {
                    Label("Research", systemImage: selectedTab == .research ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .tag(AppTab.research)

            SettingsView(settingsFocus: $settingsFocus)
                .tabItem {
                    Label("Settings", systemImage: selectedTab == .settings ? "gearshape.fill" : "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(BrandPrimary.color)
        .appMainTabBarChrome()
        .appClearUIKitBackground()
        .task(id: auth.accessToken) {
            guard let accessToken = auth.accessToken else { return }
            await account.loadPlanIfNeeded(accessToken: accessToken)
        }
    }
}

#Preview {
    AppPreview.environments {
        MainTabView()
            .environment(AuthSession())
            .environment(AccountContext())
            .environment(AssistantPresenter())
            .environment(AppBootstrapState())
            .environment(AppBrowserRouter())
    }
}
