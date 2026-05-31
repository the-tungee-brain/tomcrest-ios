import Foundation

enum AppConfig {
    /// Production API — matches my-pocket `lib/config.ts`.
    static let apiBaseURL = URL(string: "https://thetungeebrain.duckdns.org/api/v1")!

    /// Google Cloud **iOS** OAuth client ID (bundle `com.tomcrest.app`).
    static let googleClientID = "516814280647-h8h4ehcm6cpc925ndpmghh9mbcph9kqb.apps.googleusercontent.com"

    /// Web OAuth client ID — must match backend `GOOGLE_CLIENT_ID` and my-pocket `NEXT_PUBLIC_AUTH_GOOGLE_ID`.
    /// Used as `serverClientID` so the ID token audience matches backend verification.
    static let googleServerClientID =
        "516814280647-mr6ld3prc968m1a6qn0l5f06f76l1tq6.apps.googleusercontent.com"

    /// iOS URL scheme from Google Cloud Console (Reversed client ID).
    /// Example: `com.googleusercontent.apps.516814280647-abcdef`
    static let googleReversedClientID = "com.googleusercontent.apps.516814280647-h8h4ehcm6cpc925ndpmghh9mbcph9kqb"

    static var isGoogleSignInConfigured: Bool {
        !googleClientID.hasPrefix("REPLACE_") && !googleReversedClientID.hasPrefix("REPLACE_")
    }

    /// Custom URL scheme for Schwab OAuth callback (`tomcrest://schwab?status=...`).
    static let schwabCallbackURLScheme = "tomcrest"

    static let brandName = "Tomcrest"
    static let brandTagline = "AI portfolio intelligence"
    static let supportEmail = "support@tomcrest.com"
    static let websiteBaseURL = URL(string: "https://tomcrest.com")!

    static let securityURL = URL(string: "https://tomcrest.com/security")!
    static let privacyURL = URL(string: "https://tomcrest.com/privacy")!
    static let termsURL = URL(string: "https://tomcrest.com/terms")!
}
