import Foundation

struct GoogleSignInRequest: Encodable {
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

/// Accepts snake_case or camelCase auth token payloads from the API.
struct AuthTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String

    init(from decoder: Decoder) throws {
        if let snake = try? decoder.container(keyedBy: SnakeKeys.self),
           let token = try? snake.decode(String.self, forKey: .accessToken),
           !token.isEmpty {
            accessToken = token
            tokenType = (try? snake.decode(String.self, forKey: .tokenType)) ?? "bearer"
            return
        }

        let camel = try decoder.container(keyedBy: CamelKeys.self)
        accessToken = try camel.decode(String.self, forKey: .accessToken)
        tokenType = (try? camel.decode(String.self, forKey: .tokenType)) ?? "bearer"
    }

    private enum SnakeKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }

    private enum CamelKeys: String, CodingKey {
        case accessToken
        case tokenType
    }
}

typealias GoogleSignInResponse = AuthTokenResponse
typealias AuthRefreshResponse = AuthTokenResponse

struct SchwabConnectResponse: Decodable {
    let authURL: String

    enum CodingKeys: String, CodingKey {
        case authURL = "auth_url"
    }
}

struct SchwabStatusResponse: Decodable {
    let authorized: Bool
}

struct SchwabDisconnectResponse: Decodable {
    let disconnected: Bool
}

struct WaitlistErrorDetail: Decodable {
    let code: String?
    let message: String?
}

struct APIErrorEnvelope: Decodable {
    let detail: APIErrorDetailValue?

    enum APIErrorDetailValue: Decodable {
        case string(String)
        case object(WaitlistErrorDetail)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self = .string(value)
                return
            }
            self = .object(try container.decode(WaitlistErrorDetail.self))
        }
    }
}

struct SchwabReauthDetail: Decodable {
    let message: String?
    let reauthRequired: Bool?
    let authorizationURL: String?

    enum CodingKeys: String, CodingKey {
        case message
        case reauthRequired = "reauth_required"
        case authorizationURL = "authorization_url"
    }

    var requiresReauth: Bool {
        reauthRequired == true
    }
}
