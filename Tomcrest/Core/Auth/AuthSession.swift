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
    private let refreshAccessTokenRequest: ((String) async throws -> AuthRefreshResponse)?
    private let saveAccessToken: (String) throws -> Void
    @ObservationIgnored private var refreshTask: Task<String?, Never>?

    init(
        api: APIClient = .shared,
        refreshAccessTokenRequest: ((String) async throws -> AuthRefreshResponse)? = nil,
        saveAccessToken: @escaping (String) throws -> Void = KeychainTokenStore.save
    ) {
        self.api = api
        self.refreshAccessTokenRequest = refreshAccessTokenRequest
        self.saveAccessToken = saveAccessToken
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
        try saveAccessToken(accessToken)
        self.accessToken = accessToken
        lastError = nil
        phase = .signedIn
    }

    func markWaitlist() {
        lastError = nil
        phase = .waitlist
    }

    func signOut() {
        GoogleSignInCoordinator.signOut()
        KeychainTokenStore.delete()
        accessToken = nil
        lastError = nil
        phase = .signedOut
        NotificationCenter.default.post(name: .tomcrestSignedOut, object: nil)
    }

    func handleUnauthorized() {
        guard phase == .signedIn else { return }
        signOut()
        lastError = "Your session expired. Please sign in again."
    }

    func refreshAccessToken() async -> String? {
        if let refreshTask {
            return await refreshTask.value
        }

        guard let accessToken else { return nil }

        let task = Task<String?, Never> { [weak self, accessToken] in
            guard let self else { return nil }
            do {
                let response = try await self.requestRefreshedAccessToken(accessToken)
                try self.completeSignIn(accessToken: response.accessToken)
                return response.accessToken
            } catch {
                return nil
            }
        }
        refreshTask = task

        let refreshedToken = await task.value
        refreshTask = nil
        return refreshedToken
    }

    private func requestRefreshedAccessToken(_ accessToken: String) async throws -> AuthRefreshResponse {
        if let refreshAccessTokenRequest {
            return try await refreshAccessTokenRequest(accessToken)
        }
        return try await api.postNoBody(
            "/auth/refresh",
            accessToken: accessToken
        )
    }

    func setError(_ message: String) {
        lastError = message
    }

    func clearError() {
        lastError = nil
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
                if let message, !message.isAuthCancellationNoise {
                    lastError = message
                }
            default:
                lastError = error.errorDescription
            }
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            let message = error.localizedDescription
            guard !message.isAuthCancellationNoise else { return }
            lastError = message
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
                query: ["client": "ios"],
                accessToken: accessToken
            )
            return URL(string: response.authURL)
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func connectSchwab() async -> SchwabOAuthResult {
        clearError()
        guard let authURL = await fetchSchwabConnectURL() else {
            return .failed(lastError ?? "Could not start Schwab connection.")
        }

        do {
            return try await SchwabOAuthCoordinator.shared.start(authURL: authURL)
        } catch SchwabOAuthFailure.couldNotStart {
            let message = SchwabOAuthFailure.couldNotStart.errorDescription ?? "Could not open Schwab sign-in."
            lastError = message
            return .failed(message)
        } catch {
            let message = error.localizedDescription
            lastError = message
            return .failed(message)
        }
    }

    func disconnectSchwab() async -> Bool {
        clearError()
        guard let accessToken else {
            lastError = APIError.missingToken.errorDescription
            return false
        }

        do {
            let response: SchwabDisconnectResponse = try await api.delete(
                "/auth/schwab/disconnect",
                accessToken: accessToken
            )
            return response.disconnected
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func reconnectSchwabIfNeeded(from error: APIError) async -> SchwabOAuthResult? {
        guard case let .schwabReauth(detail) = error else { return nil }
        lastError = detail.message

        if let authorizationURL = detail.authorizationURL,
           let url = URL(string: authorizationURL) {
            do {
                return try await SchwabOAuthCoordinator.shared.start(authURL: url)
            } catch {
                lastError = error.localizedDescription
                return .failed(error.localizedDescription)
            }
        }

        return await connectSchwab()
    }
}
