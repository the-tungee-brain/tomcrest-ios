import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth
    @State private var browserURL: IdentifiableURL?

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
                    .appInAppBrowser($browserURL)
                case .waitlist:
                    NavigationStack {
                        WaitlistView()
                    }
                    .appInAppBrowser($browserURL)
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
}
