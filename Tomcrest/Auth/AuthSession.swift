import Foundation

enum AuthPhase: Equatable {
    case loading
    case signedOut
    case waitlist
    case signedIn
}

@MainActor
@Observable
final class AuthSession {
    private(set) var phase: AuthPhase = .loading
    private(set) var accessToken: String?
    private(set) var lastError: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func bootstrap() {
        if let token = KeychainTokenStore.load() {
            accessToken = token
            phase = .signedIn
        } else {
            phase = .signedOut
        }
    }

    func completeSignIn(accessToken: String) throws {
        try KeychainTokenStore.save(accessToken)
        self.accessToken = accessToken
        lastError = nil
        phase = .signedIn
    }

    func markWaitlist() {
        lastError = nil
        phase = .waitlist
    }

    func signOut() {
        KeychainTokenStore.delete()
        accessToken = nil
        lastError = nil
        phase = .signedOut
    }

    func setError(_ message: String) {
        lastError = message
    }

    func exchangeGoogleIDToken(_ idToken: String) async {
        lastError = nil
        do {
            let response: GoogleSignInResponse = try await api.post(
                "/auth/google/callback",
                body: GoogleSignInRequest(idToken: idToken)
            )
            try completeSignIn(accessToken: response.accessToken)
        } catch let error as APIError {
            switch error {
            case let .waitlist(message):
                markWaitlist()
                if let message {
                    lastError = message
                }
            default:
                lastError = error.errorDescription
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func fetchSchwabStatus() async -> Bool? {
        guard let accessToken else { return nil }
        do {
            let response: SchwabStatusResponse = try await api.get(
                "/auth/schwab/status",
                accessToken: accessToken
            )
            return response.authorized
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func fetchSchwabConnectURL() async -> URL? {
        guard let accessToken else { return nil }
        do {
            let response: SchwabConnectResponse = try await api.get(
                "/auth/schwab/connect",
                accessToken: accessToken
            )
            return URL(string: response.authURL)
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }
}
