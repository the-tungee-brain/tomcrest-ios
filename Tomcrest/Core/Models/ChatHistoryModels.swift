import Foundation

struct ChatSessionSummary: Decodable, Identifiable {
    let id: String
    let title: String?
    let model: String
    let kind: String
    let createdAt: String
    let updatedAt: String
}

struct ServerChatMessage: Decodable {
    let id: Int
    let role: String
    let content: String
    let createdAt: String
}

struct ChatSessionsResponse: Decodable {
    let sessions: [ChatSessionSummary]
}

struct ChatSessionMessagesResponse: Decodable {
    let sessionId: String
    let messages: [ServerChatMessage]
}

struct DeleteChatSessionResponse: Decodable {
    let deleted: Bool
    let sessionId: String
}

struct LoadedChatHistory {
    let sessionId: String
    let messages: [ChatMessage]
}

enum ChatHistoryScope: Equatable {
    case portfolio
    case research(symbol: String)

    var titlePrefix: String {
        switch self {
        case .portfolio:
            "Portfolio:"
        case let .research(symbol):
            "Research:\(symbol.uppercased()):"
        }
    }

    var sessionKind: String {
        switch self {
        case .portfolio:
            "portfolio"
        case .research:
            "research"
        }
    }
}
