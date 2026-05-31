import Foundation

enum SettingsService {
    static func fetchAccountPlan(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> AccountPlanResponse {
        try await api.get("/account/plan", accessToken: accessToken)
    }

    static func deleteAccount(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> DeleteAccountResponse {
        try await api.delete("/account", accessToken: accessToken)
    }
}
