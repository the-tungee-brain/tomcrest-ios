import Foundation

enum PortfolioService {
    static func fetchPositions(
        accessToken: String,
        refresh: Bool = false,
        api: APIClient = .shared
    ) async throws -> PortfolioFetchResult {
        let config = APIConfiguration()
        let url = try config.url(
            path: "/get-account-positions",
            query: ["refresh": refresh ? "true" : nil]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpStatus(-1, message: "Invalid response.")
        }

        if http.statusCode == 401 {
            let decoder = JSONDecoder()
            if let reauth = try? decoder.decode(PortfolioAPIEnvelope<SchwabReauthDetail>.self, from: data),
               let detail = reauth.detail,
               detail.requiresReauth {
                throw APIError.schwabReauth(detail)
            }
            throw APIError.unauthorized
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.httpStatus(http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(AccountPositionsResponse.self, from: data)
        let payloads = try PortfolioPayloadExtractor.extract(from: data)
        return PortfolioFetchResult(
            response: decoded,
            accountPayload: payloads.0,
            positionsPayload: payloads.1
        )
    }

    static func fetchMorningBrief(
        accessToken: String,
        refresh: Bool = false,
        api: APIClient = .shared
    ) async throws -> MorningBrief {
        try await api.get(
            "/portfolio/morning-brief",
            query: ["refresh": refresh ? "true" : nil],
            accessToken: accessToken
        )
    }

    static func fetchPortfolioNews(
        accessToken: String,
        api: APIClient = .shared
    ) async throws -> PortfolioNewsResponse {
        try await api.get("/portfolio/news", accessToken: accessToken)
    }

    static func fetchRecentOrders(
        accessToken: String,
        symbol: String? = nil,
        daysBack: Int = 30,
        limit: Int = 25,
        offset: Int = 0,
        refresh: Bool = false,
        api: APIClient = .shared
    ) async throws -> RecentOrdersResponse {
        try await api.get(
            "/recent-orders",
            query: [
                "symbol": symbol,
                "days_back": String(daysBack),
                "limit": String(limit),
                "offset": String(offset),
                "refresh": refresh ? "true" : nil,
            ],
            accessToken: accessToken
        )
    }

    static func dismissAlert(
        alertId: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws {
        let _: DismissAlertResponse = try await api.postNoBody(
            "/portfolio/alerts/\(alertId)/dismiss",
            accessToken: accessToken
        )
    }

    static func streamPortfolioChat(
        account: JSONPassThrough,
        positions: JSONPassThrough,
        prompt: String,
        accessToken: String,
        model: String = ChatConfig.defaultModel,
        chatSessionId: String? = nil,
        newChatSession: Bool = false,
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> StreamCompletion {
        let bodyData = try AnalyzeChatPayloadBuilder.buildBody(
            account: account,
            positions: positions,
            prompt: prompt,
            model: model,
            chatSessionId: chatSessionId,
            newChatSession: newChatSession
        )
        return try await StreamingAPIClient.streamPost(
            path: "/analyze-positions-by-symbol",
            bodyData: bodyData,
            accessToken: accessToken,
            onChunk: onChunk
        )
    }

    static func fetchStructuredPortfolioAnalysis(
        account: JSONPassThrough,
        positions: JSONPassThrough,
        accessToken: String,
        model: String = ChatConfig.defaultModel,
        onStatus: (@Sendable (String) -> Void)? = nil
    ) async throws -> StructuredAnalyzeResponse {
        let bodyData = try AnalyzeChatPayloadBuilder.buildStructuredAnalyzeBody(
            account: account,
            positions: positions,
            symbol: nil,
            userDisplayMessage: StructuredAnalysisSupport.portfolioDisplayMessage,
            model: model
        )

        let buffer = StreamingTextBuffer()
        _ = try await StreamingAPIClient.streamPost(
            path: "/analyze-positions-by-symbol",
            bodyData: bodyData,
            accessToken: accessToken
        ) { chunk in
            buffer.append(chunk)
            onStatus?(chunk)
        }
        return StructuredAnalysisSupport.parseResponse(buffer.value)
    }

    static func fetchStructuredSymbolAnalysis(
        account: JSONPassThrough,
        positions: JSONPassThrough,
        symbol: String,
        accessToken: String,
        model: String = ChatConfig.defaultModel,
        onStatus: (@Sendable (String) -> Void)? = nil
    ) async throws -> StructuredAnalyzeResponse {
        let bodyData = try AnalyzeChatPayloadBuilder.buildStructuredAnalyzeBody(
            account: account,
            positions: positions,
            symbol: symbol.uppercased(),
            userDisplayMessage: StructuredAnalysisSupport.symbolDisplayMessage(symbol),
            model: model
        )

        let buffer = StreamingTextBuffer()
        _ = try await StreamingAPIClient.streamPost(
            path: "/analyze-positions-by-symbol",
            bodyData: bodyData,
            accessToken: accessToken
        ) { chunk in
            buffer.append(chunk)
            onStatus?(chunk)
        }
        return StructuredAnalysisSupport.parseResponse(buffer.value)
    }
}

enum PortfolioBriefText {
    static func lead(from brief: PortfolioIntelligence?, changes: PortfolioChanges?) -> String? {
        let signals = brief?.signals ?? []
        if let urgent = signals.first(where: { $0.severity == .critical || $0.severity == .warning }) {
            return urgent.message
        }
        if let summary = changes?.summary, !summary.isEmpty {
            return summary
        }
        if let regime = brief?.digest?.macroRegime, !regime.isEmpty {
            return regime
        }
        if let signal = signals.first {
            return signal.message
        }
        return nil
    }

    static func formatSectorLabel(_ sector: String) -> String {
        sector
            .split(separator: "_")
            .map { part in
                part.count <= 3
                    ? part.uppercased()
                    : part.prefix(1).uppercased() + part.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

/// Reuses a recent portfolio positions response so symbol research does not refetch on every open.
@MainActor
enum PortfolioPositionsCache {
    private static var stored: PortfolioFetchResult?
    private static var storedAt: Date?
    private static let maxAge: TimeInterval = 120

    static func store(_ result: PortfolioFetchResult) {
        stored = result
        storedAt = Date()
    }

    static func cached(ttl: TimeInterval? = nil) -> PortfolioFetchResult? {
        guard let stored, let storedAt else { return nil }
        let maxAge = ttl ?? Self.maxAge
        guard Date().timeIntervalSince(storedAt) <= maxAge else { return nil }
        return stored
    }

    static func clear() {
        stored = nil
        storedAt = nil
    }
}

enum PortfolioAlerts {
    static func merged(
        proactive: [ProactiveAlert],
        brief: PortfolioIntelligence?
    ) -> [ProactiveAlert] {
        var seen = Set<String>()
        var result: [ProactiveAlert] = []

        for alert in (brief?.alerts ?? []) + proactive {
            let key = "\(alert.action)-\(alert.symbol ?? "")-\(alert.label)"
            guard seen.insert(key).inserted else { continue }
            result.append(alert)
        }

        return result.sorted { $0.priority > $1.priority }
    }
}

private struct PortfolioAPIEnvelope<T: Decodable>: Decodable {
    let detail: T?
}

/// Serial stream chunks into one string without mutating captured locals in `@Sendable` closures.
private final class StreamingTextBuffer: @unchecked Sendable {
    private var text = ""

    func append(_ chunk: String) {
        text += chunk
    }

    var value: String { text }
}
