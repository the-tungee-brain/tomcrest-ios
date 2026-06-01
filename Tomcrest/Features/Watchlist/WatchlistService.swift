import Foundation

enum WatchlistService {
    static func fetchWorkspace(
        accessToken: String,
        includeQuotes: Bool = true,
        api: APIClient = .shared
    ) async throws -> WatchlistWorkspaceResponse {
        try await api.get(
            "/watchlist/workspace",
            query: ["includeQuotes": includeQuotes ? "true" : "false"],
            accessToken: accessToken
        )
    }

    static func syncWorkspace(
        _ payload: WatchlistWorkspaceSyncRequest,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> WatchlistWorkspaceResponse {
        try await api.put(
            "/watchlist/workspace",
            body: payload,
            accessToken: accessToken
        )
    }
}
