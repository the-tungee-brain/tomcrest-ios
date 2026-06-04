import Foundation

/// How `JSONDecoder` maps JSON keys to Swift properties.
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

    private let config: APIConfiguration
    private let session: URLSession
    private let snakeCaseDecoder: JSONDecoder
    private let camelCaseDecoder: JSONDecoder
    private let encoder: JSONEncoder
    private var tokenRefresher: (@Sendable () async -> String?)?

    init(
        config: APIConfiguration = APIConfiguration(),
        session: URLSession = .shared
    ) {
        self.config = config
        self.session = session
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
        keyDecoding: APIKeyDecoding = .snakeCase
    ) async throws -> T {
        let url = try config.url(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(request, isRetry: false, keyDecoding: keyDecoding)
    }

    func post<T: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        accessToken: String? = nil
    ) async throws -> T {
        let url = try config.url(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(request, isRetry: false)
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
        return try await perform(request, isRetry: false, keyDecoding: keyDecoding)
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
        return try await perform(request, isRetry: false)
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
        return try await perform(request, isRetry: false)
    }

    func delete<T: Decodable>(
        _ path: String,
        accessToken: String? = nil
    ) async throws -> T {
        let url = try config.url(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        applyHeaders(&request, accessToken: accessToken)
        return try await perform(request, isRetry: false)
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
        keyDecoding: APIKeyDecoding = .snakeCase
    ) async throws -> T {
        let decoder = decoder(for: keyDecoding)
        let (data, response) = try await session.data(for: request)
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
                return try await perform(retryRequest, isRetry: true, keyDecoding: keyDecoding)
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
