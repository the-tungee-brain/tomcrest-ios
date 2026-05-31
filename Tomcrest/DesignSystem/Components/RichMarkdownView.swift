import SwiftUI

struct RichMarkdownView: View {
    let content: String
    var font: Font = .subheadline
    var lineSpacing: CGFloat = 4

    var body: some View {
        let blocks = MarkdownBlockParser.parse(content)

        if blocks.isEmpty {
            Text("…")
                .font(font)
                .foregroundStyle(AppColors.label)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            inlineMarkdown(text)
                .font(headingFont(level))
                .foregroundStyle(AppColors.label)
                .padding(.top, level <= 2 ? 2 : 0)

        case let .paragraph(text):
            inlineMarkdown(text)
                .font(font)
                .foregroundStyle(AppColors.label)
                .lineSpacing(lineSpacing)
                .fixedSize(horizontal: false, vertical: true)

        case let .bulletList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    listRow(prefix: "•", text: item)
                }
            }

        case let .numberedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    listRow(prefix: "\(index + 1).", text: item)
                }
            }
        }
    }

    private func listRow(prefix: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(prefix)
                .font(font.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .frame(minWidth: prefix.contains(".") ? 18 : 10, alignment: .leading)

            inlineMarkdown(text)
                .font(font)
                .foregroundStyle(AppColors.label)
                .lineSpacing(lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1:
            return .headline.weight(.semibold)
        case 2:
            return .subheadline.weight(.semibold)
        default:
            return font.weight(.semibold)
        }
    }

    private func inlineMarkdown(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            return Text(attributed)
        }
        return Text(verbatim: text)
    }
}
