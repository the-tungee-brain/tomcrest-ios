import Foundation

enum StructuredAnalysisSupport {
    static let schema = "portfolio_analysis_v1"

    static let instructions = """
    Return ONLY valid JSON matching this schema (no markdown fences, no prose outside JSON):
    {
      "summary": "2-3 sentence overall read",
      "recommendedAction": {
        "title": "Short action label",
        "reason": "Why this is the best next step",
        "symbol": "OPTIONAL_TICKER or null"
      },
      "sections": [
        {
          "id": "optional_slug",
          "title": "Section title",
          "body": "Optional short paragraph",
          "bullets": ["Optional bullet points"]
        }
      ]
    }
    Use 1-3 sections max for portfolio analysis. Do NOT include Portfolio cash map, Gaps vs targets,
    Where to put money smarter, Diversification diagnosis, Portfolio snapshot, Holdings review, Trim plan,
    or Deploy plan — the UI money map card already shows cash, holdings, and trim/deploy amounts.
    Use sections for interpretation only: "Action plan (ranked)" and optionally "Risk if you do nothing".
    """

    static let portfolioDisplayMessage =
        "Analyze my portfolio for diversification and where to deploy cash."

    static func symbolDisplayMessage(_ symbol: String) -> String {
        "Analyze my \(symbol.uppercased()) position and open options."
    }

    static func stripStreamingStatusPrefix(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(?:Pulling together your holdings|Reviewing your portfolio|Looking up company data)[^\n]*\n\n"#
        guard let range = trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return content
        }
        return String(trimmed[range.upperBound...])
    }

    static func parseResponse(_ raw: String) -> StructuredAnalyzeResponse {
        let stripped = stripStreamingStatusPrefix(raw)
        guard let candidate = extractJSONCandidate(from: stripped),
              let data = candidate.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return StructuredAnalyzeResponse(analysis: nil, portfolioPrecomputed: nil, symbolPrecomputed: nil)
        }

        if let analysisObject = json["analysis"] as? [String: Any],
           let analysisData = try? JSONSerialization.data(withJSONObject: analysisObject),
           let analysis = try? JSONDecoder().decode(StructuredAnalysis.self, from: analysisData) {
            let portfolioPrecomputed = decodePortfolioPrecomputed(from: json["portfolioPrecomputed"])
            let symbolPrecomputed = decodeSymbolPrecomputed(from: json["precomputed"])
            return StructuredAnalyzeResponse(
                analysis: stripPortfolioAllocationSections(analysis),
                portfolioPrecomputed: portfolioPrecomputed,
                symbolPrecomputed: symbolPrecomputed
            )
        }

        if let analysis = try? JSONDecoder().decode(StructuredAnalysis.self, from: data) {
            return StructuredAnalyzeResponse(analysis: analysis, portfolioPrecomputed: nil, symbolPrecomputed: nil)
        }

        return StructuredAnalyzeResponse(analysis: nil, portfolioPrecomputed: nil, symbolPrecomputed: nil)
    }

    static func stripPortfolioAllocationSections(_ analysis: StructuredAnalysis) -> StructuredAnalysis {
        let blocked = [
            "portfolio cash map", "gaps vs targets", "where to put money smarter",
            "diversification diagnosis", "portfolio snapshot", "holdings review",
            "holding-by-holding", "cash map", "trim plan", "deploy plan", "concentration check",
        ]
        return analysis.filteringSections { section in
            let title = section.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return !blocked.contains(where: { title.contains($0) })
        }
    }

    private static func decodePortfolioPrecomputed(from value: Any?) -> PortfolioAnalysisPrecomputed? {
        guard let dictionary = jsonDictionary(from: value),
              let data = try? JSONBodyEncoding.data(from: dictionary) else { return nil }
        return try? JSONDecoder().decode(PortfolioAnalysisPrecomputed.self, from: data)
    }

    private static func decodeSymbolPrecomputed(from value: Any?) -> SymbolAnalysisPrecomputed? {
        guard let dictionary = jsonDictionary(from: value),
              let data = try? JSONBodyEncoding.data(from: dictionary) else { return nil }
        return try? JSONDecoder().decode(SymbolAnalysisPrecomputed.self, from: data)
    }

    private static func jsonDictionary(from value: Any?) -> [String: Any]? {
        guard let value, !(value is NSNull) else { return nil }
        return value as? [String: Any]
    }

    static func hasComparePaths(_ precomputed: SymbolAnalysisPrecomputed?) -> Bool {
        guard let precomputed else { return false }
        return precomputed.heldOptionOutcomes.contains { !$0.comparePaths.isEmpty }
    }

    static func inferRecommendedComparePath(from title: String?) -> String? {
        guard let title else { return nil }
        let lower = title.lowercased()
        if lower.contains("roll") { return "roll" }
        if lower.contains("close") || lower.contains("buy back") { return "close" }
        if lower.contains("hold") || lower.contains("let") { return "hold" }
        return nil
    }

    private static func extractJSONCandidate(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let regex = try? NSRegularExpression(
            pattern: #"```(?:json)?\s*([\s\S]*?)```"#,
            options: [.caseInsensitive]
        ),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           match.numberOfRanges > 1,
           let capture = Range(match.range(at: 1), in: trimmed) {
            let fenced = String(trimmed[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let start = fenced.firstIndex(of: "{"),
               let end = fenced.lastIndex(of: "}"),
               start < end {
                return String(fenced[start ... end])
            }
        }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}"),
           start < end {
            return String(trimmed[start ... end])
        }
        return nil
    }
}
