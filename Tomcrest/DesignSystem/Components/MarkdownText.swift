import SwiftUI

struct MarkdownText: View {
    let content: String
    var font: Font = .subheadline
    var lineSpacing: CGFloat = 4

    var body: some View {
        Group {
            if content.isEmpty {
                Text("…")
                    .font(font)
                    .foregroundStyle(AppColors.label)
            } else {
                RichMarkdownView(content: content, font: font, lineSpacing: lineSpacing)
            }
        }
        .textSelection(.enabled)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
