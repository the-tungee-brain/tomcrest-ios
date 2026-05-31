import Foundation

struct ChatFollowUpSuggestion: Identifiable, Equatable {
    let id: String
    let label: String
    let prompt: String
}

enum ChatFollowUpSuggestions {
    private static let blockStart = "<<TOMCREST_FOLLOW_UPS>>"
    private static let blockEnd = "<<END_TOMCREST_FOLLOW_UPS>>"
    private static let blockPattern =
        #"<<TOMCREST_FOLLOW_UPS>>\s*([\s\S]*?)\s*<<END_TOMCREST_FOLLOW_UPS>>"#

    static func stripFollowUpBlock(_ content: String, isStreaming: Bool = false) -> String {
        if let range = content.range(of: blockStart) {
            return String(content[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard isStreaming else { return content }

        for length in stride(from: blockStart.count - 1, through: 1, by: -1) {
            let prefix = String(blockStart.prefix(length))
            if content.hasSuffix(prefix) {
                return String(content.dropLast(length)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return content
    }

    static func getVisibleAssistantContent(_ content: String, isStreaming: Bool = false) -> String {
        let withoutStatus = isStreaming ? content : ConversationalContentFormatting.stripStreamingStatusPrefix(content)
        return stripFollowUpBlock(withoutStatus, isStreaming: isStreaming)
    }

    static func parseFollowUps(_ content: String) -> [ChatFollowUpSuggestion] {
        guard let regex = try? NSRegularExpression(pattern: blockPattern, options: []) else {
            return []
        }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, options: [], range: range),
              match.numberOfRanges > 1,
              let jsonRange = Range(match.range(at: 1), in: content) else {
            return []
        }

        let jsonString = String(content[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        var suggestions: [ChatFollowUpSuggestion] = []
        for (index, item) in parsed.enumerated() {
            guard let label = item["label"] as? String,
                  let prompt = item["prompt"] as? String else { continue }

            let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLabel.isEmpty, !trimmedPrompt.isEmpty else { continue }

            suggestions.append(
                ChatFollowUpSuggestion(
                    id: "follow-up-\(index + 1)",
                    label: String(trimmedLabel.prefix(80)),
                    prompt: String(trimmedPrompt.prefix(500))
                )
            )
            if suggestions.count >= 3 { break }
        }

        return suggestions
    }

    static func shouldShowFollowUps(
        messages: [ChatMessage],
        messageIndex: Int,
        isLoading: Bool
    ) -> Bool {
        guard !isLoading,
              messages.indices.contains(messageIndex),
              messages[messageIndex].role == .assistant else {
            return false
        }

        let hasLaterUserMessage = messages[(messageIndex + 1)...].contains { $0.role == .user }
        if hasLaterUserMessage { return false }

        guard let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }),
              lastAssistantIndex == messageIndex else {
            return false
        }

        return !parseFollowUps(messages[messageIndex].content).isEmpty
    }
}
