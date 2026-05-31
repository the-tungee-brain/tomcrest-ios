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
    @State private var settingsFocus: SettingsFocus?

    var body: some View {
        TabView(selection: $selectedTab) {
            PortfolioView(selectedTab: $selectedTab, settingsFocus: $settingsFocus)
                .tabItem {
                    Label("Portfolio", systemImage: selectedTab == .portfolio ? "chart.pie.fill" : "chart.pie")
                }
                .tag(AppTab.portfolio)

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
            await account.loadPlan(accessToken: accessToken)
        }
    }
}

#Preview {
    AppPreview.environments {
        MainTabView()
            .environment(AuthSession())
            .environment(AccountContext())
            .environment(AssistantPresenter())
            .environment(AppBrowserRouter())
    }
}
