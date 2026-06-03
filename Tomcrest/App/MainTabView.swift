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
    @State private var tabReselect = TabBarReselectCoordinator()

    var body: some View {
        TabView(selection: $selectedTab) {
            PortfolioView(selectedTab: $selectedTab, settingsFocus: $settingsFocus)
                .tabItem { Label("Portfolio", systemImage: "chart.pie") }
                .tag(AppTab.portfolio)

            TopMoversView()
                .tabItem { Label("Movers", systemImage: "arrow.up.right.circle") }
                .tag(AppTab.movers)

            ResearchView()
                .tabItem { Label("Research", systemImage: "magnifyingglass") }
                .tag(AppTab.research)

            SettingsView(settingsFocus: $settingsFocus)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(BrandPrimary.color)
        .toolbar(.hidden, for: .tabBar)
        .appClearUIKitBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainAppTabBar(selectedTab: $selectedTab, onSelect: selectTab)
        }
        .environment(tabReselect)
        .task(id: auth.accessToken) {
            guard let accessToken = auth.accessToken else { return }
            await account.loadPlanIfNeeded(accessToken: accessToken)
        }
    }

    private func selectTab(_ tab: AppTab) {
        if selectedTab == tab {
            tabReselect.noteReselect(tab)
        }
        selectedTab = tab
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
