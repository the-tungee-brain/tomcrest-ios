import SwiftUI

struct MarkdownText: View {
    let content: String
    var font: Font = .subheadline

    var body: some View {
        Group {
            if content.isEmpty {
                Text("…")
            } else if let attributed = try? AttributedString(
                markdown: content,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            ) {
                Text(attributed)
            } else {
                Text(content)
            }
        }
        .font(font)
        .foregroundStyle(AppColors.label)
        .textSelection(.enabled)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
