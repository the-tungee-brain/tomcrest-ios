import Foundation

enum ChatService {
    static func listSessions(
        accessToken: String,
        kind: String,
        limit: Int = 50,
        api: APIClient = .shared
    ) async throws -> [ChatSessionSummary] {
        let response: ChatSessionsResponse = try await api.get(
            "/chat/sessions",
            query: [
                "kind": kind,
                "limit": String(limit),
            ],
            accessToken: accessToken
        )
        return response.sessions
    }

    static func fetchMessages(
        sessionId: String,
        accessToken: String,
        limit: Int = 100,
        api: APIClient = .shared
    ) async throws -> [ServerChatMessage] {
        let response: ChatSessionMessagesResponse = try await api.get(
            "/chat/sessions/\(sessionId)/messages",
            query: ["limit": String(limit)],
            accessToken: accessToken
        )
        return response.messages
    }

    static func deleteSession(
        sessionId: String,
        accessToken: String,
        api: APIClient = .shared
    ) async throws {
        let _: DeleteChatSessionResponse = try await api.delete(
            "/chat/sessions/\(sessionId)",
            accessToken: accessToken
        )
    }
}

enum ChatHistoryLoader {
    static func loadSession(
        sessionId: String,
        accessToken: String
    ) async throws -> LoadedChatHistory? {
        let messages = try await ChatService.fetchMessages(
            sessionId: sessionId,
            accessToken: accessToken
        )
        let mapped = mapServerMessages(messages)
        guard !mapped.isEmpty else { return nil }
        return LoadedChatHistory(sessionId: sessionId, messages: mapped)
    }

    static func loadLatest(
        scope: ChatHistoryScope,
        accessToken: String
    ) async throws -> LoadedChatHistory? {
        let sessions = try await ChatService.listSessions(
            accessToken: accessToken,
            kind: scope.sessionKind
        )
        guard let session = findLatestSession(
            sessions: sessions,
            titlePrefix: scope.titlePrefix
        ) else {
            return nil
        }

        return try await loadSession(sessionId: session.id, accessToken: accessToken)
    }

    static func hydrate(
        scope: ChatHistoryScope,
        sessionId: String?,
        localMessages: [ChatMessage],
        accessToken: String
    ) async -> LoadedChatHistory? {
        do {
            if let sessionId {
                return try await loadSession(sessionId: sessionId, accessToken: accessToken)
            }
            if !localMessages.isEmpty {
                return nil
            }
            return try await loadLatest(scope: scope, accessToken: accessToken)
        } catch {
            return nil
        }
    }

    static func shouldApplyServerHistory(
        localMessages: [ChatMessage],
        serverMessages: [ChatMessage]
    ) -> Bool {
        if serverMessages.isEmpty { return false }
        if localMessages.isEmpty { return true }
        return serverMessages.count >= localMessages.count
    }

    static func findLatestSession(
        sessions: [ChatSessionSummary],
        titlePrefix: String
    ) -> ChatSessionSummary? {
        sessions
            .filter { ($0.title ?? "").hasPrefix(titlePrefix) }
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    private static func mapServerMessages(_ messages: [ServerChatMessage]) -> [ChatMessage] {
        messages.compactMap { message in
            guard message.role == "user" || message.role == "assistant" else { return nil }
            return ChatMessage(
                id: "server-\(message.id)",
                role: message.role == "user" ? .user : .assistant,
                content: message.content
            )
        }
    }
}
