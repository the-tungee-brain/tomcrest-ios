import SwiftUI

struct SignInView: View {
    @Environment(AuthSession.self) private var auth
    @State private var isSigningIn = false

    var body: some View {
        AppAuthScreen(
            brandImageName: "BrandLogo",
            title: AppConfig.brandName,
            message: AppConfig.brandTagline
        ) {
            VStack(spacing: 16) {
                AppAuthActionPanel {
                    Button {
                        signInTapped()
                    } label: {
                        Group {
                            if isSigningIn {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(Token.onPrimary)
                                    Text("Signing in…")
                                }
                            } else {
                                Label("Continue with Google", systemImage: "g.circle.fill")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(isSigningIn)

                    Text("Read-only Schwab access. Credentials stay with Google and Schwab.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                }

                if let error = auth.lastError {
                    AppInlineBanner(message: error, tone: .error)
                }
            }
        }
    }

    private func signInTapped() {
        guard AppConfig.isGoogleSignInConfigured else {
            auth.setError(
                "Set googleClientID and googleReversedClientID in AppConfig.swift, " +
                    "and match the URL scheme in Info.plist."
            )
            return
        }

        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                let idToken = try await GoogleSignInCoordinator.signIn()
                await auth.exchangeGoogleIDToken(idToken)
            } catch GoogleSignInFailure.cancelled {
                return
            } catch {
                auth.setError(error.localizedDescription)
            }
        }
    }
}

struct WaitlistView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        AppAuthScreen(
            brandImageName: "BrandLogo",
            title: "Private beta",
            message: "Tomcrest is invite-only. Join the waitlist, then return after you're approved."
        ) {
            VStack(spacing: 16) {
                AppExternalLink(url: URL(string: "https://tomcrest.com/waitlist")!) {
                    Text("tomcrest.com/waitlist")
                        .font(.headline)
                        .foregroundStyle(AppColors.accent)
                }

                Button("Back to sign in") {
                    auth.signOut()
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }
        }
    }
}

#Preview("Sign in") {
    AppPreview.environments {
        SignInView()
            .environment(AuthSession())
    }
}

#Preview("Waitlist") {
    AppPreview.environments {
        WaitlistView()
            .environment(AuthSession())
    }
}
