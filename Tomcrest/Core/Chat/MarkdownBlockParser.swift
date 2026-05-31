import Foundation

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bulletList([String])
    case numberedList([String])
}

enum MarkdownBlockParser {
    static func parse(_ content: String) -> [MarkdownBlock] {
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var bulletItems: [String] = []
        var numberedItems: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let text = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
            paragraphLines = []
        }

        func flushBullets() {
            guard !bulletItems.isEmpty else { return }
            blocks.append(.bulletList(bulletItems))
            bulletItems = []
        }

        func flushNumbered() {
            guard !numberedItems.isEmpty else { return }
            blocks.append(.numberedList(numberedItems))
            numberedItems = []
        }

        func flushAll() {
            flushParagraph()
            flushBullets()
            flushNumbered()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushAll()
                continue
            }

            if let heading = parseHeading(trimmed) {
                flushAll()
                blocks.append(heading)
                continue
            }

            if let bullet = parseBullet(trimmed) {
                flushParagraph()
                flushNumbered()
                bulletItems.append(bullet)
                continue
            }

            if let numbered = parseNumbered(trimmed) {
                flushParagraph()
                flushBullets()
                numberedItems.append(numbered)
                continue
            }

            if !bulletItems.isEmpty || !numberedItems.isEmpty {
                flushBullets()
                flushNumbered()
            }

            paragraphLines.append(trimmed)
        }

        flushAll()
        return blocks
    }

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        if let match = line.firstMatch(of: /^(#{1,6})\s+(.+)$/) {
            return .heading(level: match.1.count, text: String(match.2))
        }

        if let match = line.firstMatch(of: /^\*\*(.+)\*\*$/),
           !String(match.1).contains("\n") {
            return .heading(level: 3, text: String(match.1))
        }

        return nil
    }

    private static func parseBullet(_ line: String) -> String? {
        if let match = line.firstMatch(of: /^[-*•]\s+(.+)$/) {
            return String(match.1)
        }
        return nil
    }

    private static func parseNumbered(_ line: String) -> String? {
        if let match = line.firstMatch(of: /^\d+[.)]\s+(.+)$/) {
            return String(match.1)
        }
        return nil
    }
}
