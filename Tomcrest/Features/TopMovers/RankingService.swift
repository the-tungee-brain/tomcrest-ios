import Foundation

enum RankingService {
    static func fetchRankingsTop(
        accessToken: String,
        limit: Int = 20,
        api: APIClient = .shared
    ) async throws -> RankingsTopResponse {
        try await api.get(
            "/rankings/top",
            query: ["limit": String(limit)],
            accessToken: accessToken
        )
    }

    static func fetchSystemHealth(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> SystemHealthResponse {
        try await api.get("/health", accessToken: accessToken)
    }

    static func lookupSymbol(
        symbol: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> TickerSymbolItem {
        try await api.get(
            "/symbols/lookup",
            query: ["symbol": symbol.uppercased()],
            accessToken: accessToken
        )
    }

    /// Lightweight decode — only symbols needed for portfolio badge.
    static func fetchPortfolioSymbols(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> Set<String> {
        let payload: PortfolioSymbolsPayload = try await api.get(
            "/portfolio/latest",
            accessToken: accessToken
        )
        return Set(payload.holdings.map { $0.symbol.uppercased() })
    }
}

private struct PortfolioSymbolsPayload: Decodable {
    let holdings: [PortfolioSymbolRow]
}

private struct PortfolioSymbolRow: Decodable {
    let symbol: String
}
