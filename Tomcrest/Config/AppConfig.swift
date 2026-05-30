import Foundation

enum AppConfig {
    /// Production API — matches my-pocket `lib/config.ts`.
    static let apiBaseURL = URL(string: "https://thetungeebrain.duckdns.org/api/v1")!

    /// Replace with your Google iOS OAuth client ID from Google Cloud Console.
    /// Must match bundle ID `com.tomcrest.app`.
    static let googleClientID = "REPLACE_WITH_GOOGLE_IOS_CLIENT_ID"

    static let brandName = "Tomcrest"
    static let brandTagline = "AI portfolio intelligence"
    static let supportEmail = "support@tomcrest.com"
}
