import SwiftUI

@main
struct TomcrestApp: App {
    @State private var auth = AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .preferredColorScheme(.dark)
                .task {
                    auth.bootstrap()
                }
        }
    }
}
