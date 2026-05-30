import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        Group {
            switch auth.phase {
            case .loading:
                ProgressView("Loading…")
                    .tint(Theme.accent)
            case .signedOut:
                SignInView()
            case .waitlist:
                WaitlistView()
            case .signedIn:
                MainTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

#Preview {
    RootView()
        .environment(AuthSession())
}
