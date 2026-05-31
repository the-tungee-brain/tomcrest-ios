import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        Group {
            switch auth.phase {
            case .loading:
                AppLoadingState(message: "Loading…")
            case .signedOut:
                SignInView()
            case .waitlist:
                WaitlistView()
            case .signedIn:
                MainTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
    }
}

#Preview {
    RootView()
        .environment(AuthSession())
        .environment(AccountContext())
}
