import SwiftUI

struct ConversationalMarkdownText: View {
    let content: String
    var isStreaming = false

    var body: some View {
        let visible = ChatFollowUpSuggestions.getVisibleAssistantContent(content, isStreaming: isStreaming)
        let trimmed = visible.trimmingCharacters(in: .whitespacesAndNewlines)

        Group {
            if isStreaming, trimmed.isEmpty {
                Text("…")
            } else if isStreaming {
                HStack(alignment: .top, spacing: 0) {
                    Text(verbatim: trimmed)
                        .lineSpacing(4)
                    Text("|")
                        .foregroundStyle(AppColors.accentHighlight)
                        .opacity(0.85)
                }
            } else {
                RichMarkdownView(
                    content: ConversationalContentFormatting.preprocessForMarkdown(trimmed),
                    font: .system(size: 15),
                    lineSpacing: 4
                )
            }
        }
        .font(.system(size: 15))
        .foregroundStyle(AppColors.label)
        .multilineTextAlignment(.leading)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
}
