import Foundation

struct GoogleSignInRequest: Encodable {
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

struct GoogleSignInResponse: Decodable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct AuthRefreshResponse: Decodable {
    let accessToken: String
    let tokenType: String
}

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
