import SwiftUI

struct RichMarkdownView: View {
    let content: String
    var font: Font = .subheadline
    var lineSpacing: CGFloat = 4

    @State private var blocks: [MarkdownBlock] = []

    var body: some View {
        Group {
            if blocks.isEmpty {
                Text("…")
                    .font(font)
                    .foregroundStyle(AppColors.label)
                    .redacted(reason: content.isEmpty ? [] : .placeholder)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(blocks, id: \.renderID) { block in
                        blockView(block)
                    }
                }
            }
        }
        .task(id: content) {
            let parsed = await Task.detached(priority: .userInitiated) {
                MarkdownBlockParser.parse(content)
            }.value
            blocks = parsed
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
                ForEach(Array(items.enumerated()), id: \.element) { _, item in
                    listRow(prefix: "•", text: item)
                }
            }

        case let .numberedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.element) { index, item in
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

private extension MarkdownBlock {
    var renderID: String {
        switch self {
        case let .heading(level, text):
            return "h\(level):\(text)"
        case let .paragraph(text):
            return "p:\(text)"
        case let .bulletList(items):
            return "ul:\(items.joined(separator: "\u{1F}"))"
        case let .numberedList(items):
            return "ol:\(items.enumerated().map { "\($0.offset):\($0.element)" }.joined(separator: "\u{1F}"))"
        }
    }
}
