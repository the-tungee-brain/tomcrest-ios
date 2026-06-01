import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AppBrowserRouter.self) private var browser
    @Environment(AppBootstrapState.self) private var bootstrap

    var body: some View {
        ZStack {
            AppCanvasBackground()
                .ignoresSafeArea()

            Group {
                switch auth.phase {
                case .loading:
                    if bootstrap.timedOut {
                        PortfolioLoadingView()
                            .padding(.horizontal, Layout.horizontalPadding)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        Color.clear
                    }
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
        .environment(AppBootstrapState())
        .environment(AppBrowserRouter())
}
