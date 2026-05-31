import Foundation

enum ConversationalContentFormatting {
    private static let statusPrefixPattern =
        #"^(?:Pulling together your holdings|Reviewing your portfolio|Looking up company data)[^\n]*\n\n"#

    static func stripStreamingStatusPrefix(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .newlines)
        guard let regex = try? NSRegularExpression(pattern: statusPrefixPattern, options: [.caseInsensitive]) else {
            return content
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              let matchRange = Range(match.range, in: trimmed) else {
            return content
        }
        return String(trimmed[matchRange.upperBound...])
    }

    /// Normalizes assistant markdown so block parsing preserves lists, breaks, and labels.
    static func preprocessForMarkdown(_ content: String) -> String {
        var text = content.replacingOccurrences(of: "\r\n", with: "\n")

        text = normalizeBulletMarkers(in: text)
        text = splitInlineSectionLabels(in: text)
        text = insertParagraphBreaks(in: text)
        text = boldStandaloneLabels(in: text)
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeBulletMarkers(in text: String) -> String {
        text
            .replacingOccurrences(
                of: #"(?m)^[\u2022\u2023\u2043\u2219]\s+"#,
                with: "- ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?m)^\*\s+"#,
                with: "- ",
                options: .regularExpression
            )
    }

    /// Turns `Section label: detail` into two lines when the label looks like a header.
    private static func splitInlineSectionLabels(in text: String) -> String {
        replacingMatches(
            in: text,
            pattern: #"(?m)^([A-Z*][^\n:]{1,45}):\s+(?=\S)"#,
            with: "$1:\n\n"
        )
    }

    private static func insertParagraphBreaks(in text: String) -> String {
        var result = replacingMatches(
            in: text,
            pattern: #"(?<=[.!?])\s*(?=[A-Z][^\n.]{2,55}:)"#,
            with: "\n\n"
        )
        result = replacingMatches(
            in: result,
            pattern: #"(?<=[.!?])\s*(?=(Why |What I |If you |Net:|Best |Lower-risk |Not a ))"#,
            with: "\n\n"
        )
        return result
    }

    private static func boldStandaloneLabels(in text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let formattedLines = lines.map { line -> String in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard trimmedLine.count >= 3,
                  trimmedLine.count <= 55,
                  trimmedLine.hasSuffix(":"),
                  !trimmedLine.hasPrefix("#"),
                  !trimmedLine.hasPrefix("-"),
                  !trimmedLine.hasPrefix("*") else {
                return line
            }
            let title = String(trimmedLine.dropLast())
            return "**\(title):**"
        }
        return formattedLines.joined(separator: "\n")
    }

    private static func replacingMatches(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
