import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case waitlist(message: String?)
    case watchlistConflict(currentVersion: Int?, baseVersion: Int?, message: String?)
    case schwabReauth(SchwabReauthDetail)
    case httpStatus(Int, message: String?)
    case decoding(Error)
    case missingToken
    case notConfigured(String)
    case requestTimeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid request URL."
        case .unauthorized:
            "Your session expired. Please sign in again."
        case let .waitlist(message):
            message ?? "Tomcrest is in private beta. Join the waitlist at tomcrest.com."
        case let .watchlistConflict(_, _, message):
            message ?? "Watchlist changed on another device."
        case let .schwabReauth(detail):
            detail.message ?? "Schwab re-authorization required."
        case let .httpStatus(code, message):
            message ?? "Request failed with status \(code)."
        case let .decoding(error):
            "Could not read server response: \(error.localizedDescription)"
        case .missingToken:
            "Not signed in."
        case let .notConfigured(message):
            message
        case .requestTimeout:
            "The server took too long to respond. Pull to refresh and try again."
        }
    }
}

struct APIConfiguration {
    let baseURL: URL

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
    }

    func url(path: String, query: [String: String?] = [:]) throws -> URL {
        guard path.hasPrefix("/") else {
            throw APIError.invalidURL
        }

        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        let items = query.compactMap { key, value -> URLQueryItem? in
            guard let value, !value.isEmpty else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        if !items.isEmpty {
            components?.queryItems = items
        }
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        return url
    }
}
