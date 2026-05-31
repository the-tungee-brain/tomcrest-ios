import GoogleSignIn
import UIKit

enum GoogleSignInFailure: LocalizedError {
    case notConfigured
    case missingPresenter
    case missingIDToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Google Sign-In is not configured. Set client IDs in AppConfig.swift and the URL scheme in Info.plist."
        case .missingPresenter:
            "Could not present Google Sign-In."
        case .missingIDToken:
            "Google did not return an ID token."
        case .cancelled:
            nil
        }
    }
}

@MainActor
enum GoogleSignInCoordinator {
    static func configure() {
        guard AppConfig.isGoogleSignInConfigured else { return }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: AppConfig.googleClientID,
            serverClientID: AppConfig.googleServerClientID
        )
    }

    static func signIn() async throws -> String {
        guard AppConfig.isGoogleSignInConfigured else {
            throw GoogleSignInFailure.notConfigured
        }

        configure()

        guard let presenter = topViewController() else {
            throw GoogleSignInFailure.missingPresenter
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw GoogleSignInFailure.missingIDToken
            }
            return idToken
        } catch let error as GIDSignInError where error.code == .canceled {
            throw GoogleSignInFailure.cancelled
        }
    }

    @discardableResult
    static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    static func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let root = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        return topMostViewController(from: root)
    }

    private static func topMostViewController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return controller
    }
}
