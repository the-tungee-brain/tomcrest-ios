import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: ChatRole
    var content: String

    enum ChatRole: String {
        case user
        case assistant
    }
}

struct StreamCompletion {
    let chatSessionId: String?
}

enum ChatConfig {
    static let defaultModel = "gpt-4.1-mini"
    static let portfolioChatKey = "__PORTFOLIO_CHAT__"
}

enum AnalyzeChatPayloadBuilder {
    static func buildBody(
        account: JSONPassThrough,
        positions: JSONPassThrough,
        prompt: String,
        model: String,
        chatSessionId: String?,
        newChatSession: Bool
    ) throws -> Data {
        let accountObject = try JSONSerialization.jsonObject(with: account.data)
        let positionsObject = try JSONSerialization.jsonObject(with: positions.data)

        var body: [String: Any] = [
            "account": accountObject,
            "positions": positionsObject,
            "symbol": NSNull(),
            "action": "free-form",
            "prompt": prompt,
            "model": model,
            "new_chat_session": newChatSession,
        ]

        if let chatSessionId {
            body["chat_session_id"] = chatSessionId
        }

        return try JSONSerialization.data(withJSONObject: body)
    }
}

enum ResearchChatPayloadBuilder {
    static func buildBody(
        symbol: String,
        prompt: String,
        model: String,
        chatSessionId: String?,
        newChatSession: Bool
    ) throws -> Data {
        var body: [String: Any] = [
            "symbol": symbol.uppercased(),
            "prompt": prompt,
            "model": model,
            "new_chat_session": newChatSession,
        ]

        if let chatSessionId {
            body["chat_session_id"] = chatSessionId
        }

        return try JSONSerialization.data(withJSONObject: body)
    }
}
