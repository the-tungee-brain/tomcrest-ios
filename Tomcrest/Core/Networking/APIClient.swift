import Foundation

/// How `JSONDecoder` maps JSON keys to Swift properties.
/// URL session profile — heavy research scans can exceed the default 60s limit.
enum APISessionKind: Sendable {
    case standard
    case longRunning
}

enum APIKeyDecoding: Sendable {
    /// `convertFromSnakeCase` — for APIs that emit `snake_case` keys matching camelCase properties
    /// without custom `CodingKeys` (rankings, portfolio, etc.).
    case snakeCase
    /// No key conversion — use for camelCase JSON **or** models with explicit `CodingKeys` string
    /// values (e.g. SEC `accession_number`). Do not pair explicit snake `CodingKeys` with `.snakeCase`.
    case camelCase
}

actor APIClient {
    static let shared = APIClient()

    private static func makeSession(requestTimeout: TimeInterval, resourceTimeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }

    private static let standardSession = makeSession(requestTimeout: 60, resourceTimeout: 90)
    private static let longRunningSession = makeSession(requestTimeout: 180, resourceTimeout: 300)

    private let config: APIConfiguration
    private let standardSession: URLSession
    private let longRunningSession: URLSession
    private let snakeCaseDecoder: JSONDecoder
    private let camelCaseDecoder: JSONDecoder
    private let encoder: JSONEncoder
    private var tokenRefresher: (@Sendable () async -> String?)?

    init(
        config: APIConfiguration = APIConfiguration(),
        standardSession: URLSession = APIClient.standardSession,
        longRunningSession: URLSession = APIClient.longRunningSession
    ) {
        self.config = config
        self.standardSession = standardSession
        self.longRunningSession = longRunningSession
        self.snakeCaseDecoder = JSONDecoder()
        self.snakeCaseDecoder.keyDecodingStrategy = .convertFromSnakeCase
        self.camelCaseDecoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func setTokenRefresher(_ refresher: (@Sendable () async -> String?)?) {
        tokenRefresher = refresher
    }

    func get<T: Decodable>(
        _ path: String,
        query: [String: String?] = [:],
        accessToken: String? = nil,
        keyDecoding: APIKeyDecoding = .snakeCase,
        sessionKind: APISessionKind = .standard
    ) async throws -> T {
        let url = try config.url(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(
            request,
            isRetry: false,
            keyDecoding: keyDecoding,
            sessionKind: sessionKind,
            allowTimeoutRetry: sessionKind == .longRunning
        )
    }

    func post<T: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        accessToken: String? = nil,
        keyDecoding: APIKeyDecoding = .snakeCase
    ) async throws -> T {
        let url = try config.url(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(
            request,
            isRetry: false,
            keyDecoding: keyDecoding,
            sessionKind: .standard,
            allowTimeoutRetry: false
        )
    }

    func postNoBody<T: Decodable>(
        _ path: String,
        query: [String: String?] = [:],
        accessToken: String? = nil,
        keyDecoding: APIKeyDecoding = .snakeCase
    ) async throws -> T {
        let url = try config.url(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(request, isRetry: false, keyDecoding: keyDecoding, sessionKind: .standard, allowTimeoutRetry: false)
    }

    func put<T: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        accessToken: String? = nil
    ) async throws -> T {
        let url = try config.url(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = try encoder.encode(body)
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(request, isRetry: false, sessionKind: .standard, allowTimeoutRetry: false)
    }

    func patch<T: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        accessToken: String? = nil
    ) async throws -> T {
        let url = try config.url(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.httpBody = try encoder.encode(body)
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(request, isRetry: false, sessionKind: .standard, allowTimeoutRetry: false)
    }

    func delete<T: Decodable>(
        _ path: String,
        accessToken: String? = nil
    ) async throws -> T {
        let url = try config.url(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(request, isRetry: false, sessionKind: .standard, allowTimeoutRetry: false)
    }

    private func session(for kind: APISessionKind) -> URLSession {
        switch kind {
        case .standard: standardSession
        case .longRunning: longRunningSession
        }
    }

    private func applyHeaders(_ request: inout URLRequest, accessToken: String?) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }

    private func decoder(for keyDecoding: APIKeyDecoding) -> JSONDecoder {
        switch keyDecoding {
        case .snakeCase: snakeCaseDecoder
        case .camelCase: camelCaseDecoder
        }
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        isRetry: Bool,
        keyDecoding: APIKeyDecoding = .snakeCase,
        sessionKind: APISessionKind = .standard,
        allowTimeoutRetry: Bool = false
    ) async throws -> T {
        let decoder = decoder(for: keyDecoding)
        let urlSession = session(for: sessionKind)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            if allowTimeoutRetry, !isRetry {
                return try await perform(
                    request,
                    isRetry: true,
                    keyDecoding: keyDecoding,
                    sessionKind: sessionKind,
                    allowTimeoutRetry: false
                )
            }
            throw APIError.requestTimeout
        } catch let error as URLError where error.code == .networkConnectionLost || error.code == .notConnectedToInternet {
            throw APIError.httpStatus(-1, message: "Network unavailable. Check your connection and try again.")
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpStatus(-1, message: "Invalid response.")
        }

        if http.statusCode == 401 {
            if let reauth = try? snakeCaseDecoder.decode(APIEnvelope<SchwabReauthDetail>.self, from: data),
               let detail = reauth.detail,
               detail.requiresReauth {
                throw APIError.schwabReauth(detail)
            }
            if !isRetry, let refresher = tokenRefresher, let newToken = await refresher() {
                var retryRequest = request
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                return try await perform(
                    retryRequest,
                    isRetry: true,
                    keyDecoding: keyDecoding,
                    sessionKind: sessionKind,
                    allowTimeoutRetry: false
                )
            }
            NotificationCenter.default.post(name: .tomcrestUnauthorized, object: nil)
            throw APIError.unauthorized
        }

        if http.statusCode == 403 {
            if let envelope = try? snakeCaseDecoder.decode(APIErrorEnvelope.self, from: data) {
                switch envelope.detail {
                case let .object(detail) where detail.code == "waitlist":
                    throw APIError.waitlist(message: detail.message)
                case let .string(message) where message.localizedCaseInsensitiveContains("waitlist"):
                    throw APIError.waitlist(message: message)
                default:
                    break
                }
            }
        }

        if http.statusCode == 409,
           let envelope = try? camelCaseDecoder.decode(APIEnvelope<WatchlistConflictDetail>.self, from: data),
           let detail = envelope.detail,
           detail.code == "watchlist_version_conflict" {
            throw APIError.watchlistConflict(
                currentVersion: detail.currentVersion,
                baseVersion: detail.baseVersion,
                message: detail.message
            )
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = parseErrorMessage(from: data)
            throw APIError.httpStatus(http.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let primaryError {
            let alternateDecoder = keyDecoding == .camelCase ? snakeCaseDecoder : camelCaseDecoder
            if let decoded = try? alternateDecoder.decode(T.self, from: data) {
                return decoded
            }
            throw APIError.decoding(primaryError)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let envelope = try? snakeCaseDecoder.decode(APIErrorEnvelope.self, from: data) {
            switch envelope.detail {
            case let .string(message):
                return message
            case let .object(detail):
                return detail.message
            case .none:
                break
            }
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct APIEnvelope<T: Decodable>: Decodable {
    let detail: T?
}
