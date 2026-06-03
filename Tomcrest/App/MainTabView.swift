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
        VStack(spacing: 0) {
            ZStack {
                AppCanvasBackground()
                    .ignoresSafeArea()

                TabLazyHost(active: selectedTab == .portfolio) {
                    PortfolioView(selectedTab: $selectedTab, settingsFocus: $settingsFocus)
                }
                .zIndex(selectedTab == .portfolio ? 1 : 0)

                TabLazyHost(active: selectedTab == .movers) {
                    TopMoversView()
                }
                .zIndex(selectedTab == .movers ? 1 : 0)

                TabLazyHost(active: selectedTab == .research) {
                    ResearchView()
                }
                .zIndex(selectedTab == .research ? 1 : 0)

                TabLazyHost(active: selectedTab == .settings) {
                    SettingsView(settingsFocus: $settingsFocus)
                }
                .zIndex(selectedTab == .settings ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MainAppTabBar(selectedTab: $selectedTab, onSelect: selectTab)
        }
        .background(AppColors.background)
        .appClearUIKitBackground()
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

// MARK: - Lazy tab mounting

/// Mounts tab content the first time it is selected and keeps it alive for state preservation.
private struct TabLazyHost<Content: View>: View {
    let active: Bool
    @ViewBuilder var content: () -> Content

    @State private var retained = false

    var body: some View {
        Group {
            if retained {
                content()
                    .opacity(active ? 1 : 0)
                    .allowsHitTesting(active)
                    .accessibilityHidden(!active)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if active {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: active, initial: true) { _, isActive in
            if isActive {
                retained = true
            }
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
