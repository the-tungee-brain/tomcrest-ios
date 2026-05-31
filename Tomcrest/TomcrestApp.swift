import SwiftUI

@main
struct TomcrestApp: App {
    @State private var auth = AuthSession()
    @State private var account = AccountContext()

    init() {
        GoogleSignInCoordinator.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(account)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    _ = GoogleSignInCoordinator.handle(url)
                }
                .task {
                    auth.bootstrap()
                }
        }
    }
}
