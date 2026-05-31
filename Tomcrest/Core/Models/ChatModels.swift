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
    static let freeDefaultModel = "gpt-4.1-mini"
    static let proDefaultModel = "gpt-5.4"
    /// Fallback before account plan loads; matches free tier default.
    static let defaultModel = freeDefaultModel
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

        return try JSONBodyEncoding.data(from: body)
    }

    static func buildStructuredAnalyzeBody(
        account: JSONPassThrough,
        positions: JSONPassThrough,
        symbol: String?,
        userDisplayMessage: String,
        model: String = ChatConfig.defaultModel
    ) throws -> Data {
        let accountObject = try JSONSerialization.jsonObject(with: account.data)
        let positionsObject = try JSONSerialization.jsonObject(with: positions.data)

        let body: [String: Any] = [
            "account": accountObject,
            "positions": positionsObject,
            "symbol": symbol ?? NSNull(),
            "action": "free-form",
            "prompt": NSNull(),
            "user_display_message": userDisplayMessage,
            "response_format": StructuredAnalysisSupport.schema,
            "analysis_instructions": StructuredAnalysisSupport.instructions,
            "model": model,
            "new_chat_session": true,
        ]

        return try JSONBodyEncoding.data(from: body)
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

        return try JSONBodyEncoding.data(from: body)
    }
}
