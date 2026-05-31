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
    @State private var assistant = AssistantPresenter()
    @State private var browser = AppBrowserRouter()

    var body: some View {
        @Bindable var browser = browser

        RootView()
            .environment(auth)
            .environment(account)
            .environment(researchBookmarks)
            .environment(assistant)
            .environment(browser)
            .appBrowserHost(browser)
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                _ = GoogleSignInCoordinator.handle(url)
            }
            .task {
                auth.bootstrap()
                let refresh: @Sendable () async -> String? = { [auth] in
                    await auth.refreshAccessToken()
                }
                await APIClient.shared.setTokenRefresher(refresh)
                StreamingAPIClient.setTokenRefresher(refresh)
            }
            .onReceive(NotificationCenter.default.publisher(for: .tomcrestUnauthorized)) { _ in
                auth.handleUnauthorized()
            }
    }
}
