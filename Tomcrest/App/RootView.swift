import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AppBrowserRouter.self) private var browser

    var body: some View {
        ZStack {
            AppCanvasBackground()
                .ignoresSafeArea()

            Group {
                switch auth.phase {
                case .loading:
                    AppLoadingState(message: "Loading…")
                case .signedOut:
                    NavigationStack {
                        SignInView()
                    }
                case .waitlist:
                    NavigationStack {
                        WaitlistView()
                    }
                case .signedIn:
                    MainTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appClearUIKitBackground()
        }
    }
}

#Preview {
    RootView()
        .environment(AuthSession())
        .environment(AccountContext())
        .environment(AppBrowserRouter())
}
