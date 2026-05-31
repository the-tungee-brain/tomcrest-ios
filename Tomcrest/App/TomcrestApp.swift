import SwiftUI

@main
struct TomcrestApp: App {
    @State private var auth = AuthSession()
    @State private var account = AccountContext()
    @State private var researchBookmarks = ResearchSymbolBookmarks()
    @State private var assistant = AssistantPresenter()

    init() {
        GoogleSignInCoordinator.configure()
        AppChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(account)
                .environment(researchBookmarks)
                .environment(assistant)
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
}
