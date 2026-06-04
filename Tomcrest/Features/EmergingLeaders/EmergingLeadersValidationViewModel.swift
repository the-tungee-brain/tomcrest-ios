import Foundation

@MainActor
@Observable
final class EmergingLeadersValidationViewModel {
    private let auth: AuthSession

    var payload: EmergingLeadersValidationResponse?
    var isLoading = false
    var errorMessage: String?

    init(auth: AuthSession) {
        self.auth = auth
    }

    var hasData: Bool {
        guard let payload else { return false }
        return payload.labeledRows > 0
    }

    func refresh() async {
        guard let accessToken = auth.accessToken, !accessToken.isEmpty else {
            errorMessage = "Sign in to view validation."
            return
        }
        isLoading = payload == nil
        errorMessage = nil
        defer { isLoading = false }
        do {
            payload = try await EmergingLeadersValidationService.fetch(accessToken: accessToken)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
