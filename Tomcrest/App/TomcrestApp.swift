import SwiftUI

@main
struct TomcrestApp: App {
    init() {
        GoogleSignInCoordinator.configure()
        AppChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
        }
    }
}

/// Owns app-wide state and wires the in-app browser at the root so every tab/sheet gets it.
private struct AppShell: View {
    @State private var auth = AuthSession()
    @State private var account = AccountContext()
    @State private var researchBookmarks = ResearchSymbolBookmarks()
    @State private var watchlistStore = WatchlistStore()
    @State private var assistant = AssistantPresenter()
    @State private var browser = AppBrowserRouter()
    @State private var bootstrap = AppBootstrapState()

    var body: some View {
        @Bindable var browser = browser

        ZStack {
            RootView()
                .environment(auth)
                .environment(account)
                .environment(researchBookmarks)
                .environment(watchlistStore)
                .environment(assistant)
                .environment(browser)
                .environment(bootstrap)
                .appBrowserHost(browser)
                .opacity(bootstrap.showBrandShell ? 0 : 1)

            if bootstrap.showBrandShell {
                BrandShellView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(BrandMotion.shellCrossfade, value: bootstrap.showBrandShell)
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            _ = GoogleSignInCoordinator.handle(url)
        }
        .task {
            watchlistStore.bind(auth: auth)
            await bootstrap.run(auth: auth, account: account, watchlistStore: watchlistStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tomcrestUnauthorized)) { _ in
            auth.handleUnauthorized()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tomcrestSignedOut)) { _ in
            SessionDataCleaner.clearLocalUserData(
                watchlistStore: watchlistStore,
                researchBookmarks: researchBookmarks,
                account: account,
                bootstrap: bootstrap
            )
        }
    }
}
