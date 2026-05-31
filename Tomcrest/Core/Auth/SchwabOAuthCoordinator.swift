import AuthenticationServices
import UIKit

enum SchwabOAuthResult: Equatable {
    case success
    case cancelled
    case failed(String)

    static func parse(from callbackURL: URL) -> SchwabOAuthResult {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let status = components.queryItems?.first(where: { $0.name == "status" })?.value
        else {
            return .failed("Unexpected Schwab callback.")
        }

        if status == "success" {
            return .success
        }

        return .failed(SchwabOAuthResult.message(for: status))
    }

    static func message(for status: String) -> String {
        switch status {
        case "error":
            "Schwab authorization was denied or failed."
        case "invalid":
            "Schwab did not return an authorization code."
        case "error_state":
            "Schwab session expired. Please try connecting again."
        case "error_token":
            "Could not complete Schwab connection. Please try again."
        default:
            "Schwab connection failed (\(status))."
        }
    }
}

enum SchwabOAuthFailure: LocalizedError {
    case couldNotStart
    case missingPresenter

    var errorDescription: String? {
        switch self {
        case .couldNotStart:
            "Could not open Schwab sign-in."
        case .missingPresenter:
            "Could not present Schwab sign-in."
        }
    }
}

@MainActor
final class SchwabOAuthCoordinator: NSObject {
    static let shared = SchwabOAuthCoordinator()

    private var session: ASWebAuthenticationSession?

    func start(authURL: URL) async throws -> SchwabOAuthResult {
        try await withCheckedThrowingContinuation { continuation in
            session?.cancel()

            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConfig.schwabCallbackURLScheme
            ) { [weak self] callbackURL, error in
                defer { self?.session = nil }

                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(returning: .cancelled)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(returning: .failed("Missing Schwab callback URL."))
                    return
                }

                continuation.resume(returning: SchwabOAuthResult.parse(from: callbackURL))
            }

            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            session = authSession

            guard authSession.start() else {
                continuation.resume(throwing: SchwabOAuthFailure.couldNotStart)
                return
            }
        }
    }
}

extension SchwabOAuthCoordinator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        return ASPresentationAnchor()
    }
}
