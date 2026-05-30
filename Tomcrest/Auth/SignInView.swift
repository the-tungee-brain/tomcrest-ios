import SwiftUI

struct SignInView: View {
    @Environment(AuthSession.self) private var auth
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)

                Text(AppConfig.brandName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.foreground)

                Text(AppConfig.brandTagline)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            VStack(spacing: 12) {
                Button {
                    signInTapped()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                        Text("Continue with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(isSigningIn)

                Text("Read-only Schwab connection. Your credentials stay with Google and Schwab.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .appPanel()

            if isSigningIn {
                ProgressView("Signing in…")
                    .tint(Theme.accent)
            }

            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
    }

    private func signInTapped() {
        guard AppConfig.googleClientID.hasPrefix("REPLACE_") == false else {
            auth.setError(
                "Set GOOGLE_IOS_CLIENT_ID in AppConfig.swift before signing in."
            )
            return
        }

        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            // Phase 1: wire GoogleSignIn-iOS SDK and pass idToken here.
            auth.setError(
                "Google Sign-In SDK not wired yet. Add the iOS client ID, then integrate GoogleSignIn."
            )
        }
    }
}

struct WaitlistView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.warning)

            Text("Private beta")
                .font(.title.bold())
                .foregroundStyle(Theme.foreground)

            Text("Tomcrest is invite-only right now. Join the waitlist at tomcrest.com, then come back after you're approved.")
                .font(.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            Link("tomcrest.com", destination: URL(string: "https://tomcrest.com/waitlist")!)
                .font(.headline)
                .foregroundStyle(Theme.accent)

            Button("Back to sign in") {
                auth.signOut()
            }
            .buttonStyle(.bordered)
            .tint(Theme.foreground)

            Spacer()
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
    }
}

#Preview("Sign in") {
    SignInView()
        .environment(AuthSession())
}

#Preview("Waitlist") {
    WaitlistView()
        .environment(AuthSession())
}
