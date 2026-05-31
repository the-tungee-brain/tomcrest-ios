import Foundation

enum StreamingAPIClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    private static var tokenRefresher: (@Sendable () async -> String?)?

    static func setTokenRefresher(_ refresher: (@Sendable () async -> String?)?) {
        tokenRefresher = refresher
    }

    static func streamPost(
        path: String,
        bodyData: Data,
        accessToken: String,
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> StreamCompletion {
        try await streamPost(
            path: path,
            bodyData: bodyData,
            accessToken: accessToken,
            isRetry: false,
            onChunk: onChunk
        )
    }

    private static func streamPost(
        path: String,
        bodyData: Data,
        accessToken: String,
        isRetry: Bool,
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> StreamCompletion {
        let config = APIConfiguration()
        let url = try config.url(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpStatus(-1, message: "Invalid streaming response.")
        }

        if http.statusCode == 401 {
            if !isRetry, let refresher = tokenRefresher, let newToken = await refresher() {
                return try await streamPost(
                    path: path,
                    bodyData: bodyData,
                    accessToken: newToken,
                    isRetry: true,
                    onChunk: onChunk
                )
            }
            NotificationCenter.default.post(name: .tomcrestUnauthorized, object: nil)
            throw APIError.unauthorized
        }

        guard (200 ... 299).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let message = String(data: errorData, encoding: .utf8)
            throw APIError.httpStatus(http.statusCode, message: message)
        }

        let chatSessionId = http.value(forHTTPHeaderField: "X-Chat-Session-Id")
        var decoder = UTF8StreamDecoder()

        do {
            for try await byte in bytes {
                if let chunk = decoder.append(byte) {
                    onChunk(chunk)
                }
            }
            if let tail = decoder.finish() {
                onChunk(tail)
            }
        } catch {
            throw error
        }

        return StreamCompletion(chatSessionId: chatSessionId)
    }
}

private struct UTF8StreamDecoder {
    private var buffer = Data()

    mutating func append(_ byte: UInt8) -> String? {
        buffer.append(byte)
        return extractCompleteString()
    }

    mutating func finish() -> String? {
        defer { buffer.removeAll() }
        guard !buffer.isEmpty else { return nil }
        return String(data: buffer, encoding: .utf8)
    }

    private mutating func extractCompleteString() -> String? {
        var searchEnd = buffer.count
        while searchEnd > 0 {
            let slice = buffer.prefix(searchEnd)
            if let string = String(data: slice, encoding: .utf8) {
                buffer.removeFirst(searchEnd)
                return string
            }
            searchEnd -= 1
        }
        return nil
    }
}
