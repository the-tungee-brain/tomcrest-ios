import Foundation

struct FinancialKeyMetric: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let note: String?
}

enum FinancialsPresentation {
    static let keyMetricSpecs: [(keys: [String], display: String)] = [
        (["Revenue growth"], "Revenue growth"),
        (["Gross margin"], "Gross margin"),
        (["Profit margin", "Net margin"], "Net margin"),
        (["Free cash flow"], "Free cash flow"),
        (["Debt / equity", "Debt/equity"], "Debt / equity"),
        (["Current ratio"], "Current ratio"),
    ]

    static let highlightFilingForms = ["10-Q", "10-K", "8-K"]

    static func pickKeyMetrics(_ metrics: [FundamentalMetric]) -> [FinancialKeyMetric] {
        guard !metrics.isEmpty else { return [] }

        var byKey: [String: FundamentalMetric] = [:]
        for metric in metrics {
            byKey[normalizeLabel(metric.label)] = metric
        }

        var picked: [FinancialKeyMetric] = []
        var used = Set<String>()

        for spec in keyMetricSpecs {
            guard let match = spec.keys
                .compactMap({ byKey[normalizeLabel($0)] })
                .first else { continue }
            let key = normalizeLabel(match.label)
            guard !used.contains(key) else { continue }
            used.insert(key)
            picked.append(
                FinancialKeyMetric(
                    label: spec.display,
                    value: match.value,
                    note: match.note
                )
            )
        }

        return picked
    }

    static func pickKeyMetricsFromRows(_ metrics: [FundamentalMetric]) -> [FinancialKeyMetric] {
        let order = keyMetricSpecs.map(\.display)
        return order.compactMap { label in
            guard let metric = metrics.first(where: { $0.label == label }) else {
                return nil
            }
            return FinancialKeyMetric(
                label: metric.label,
                value: metric.value,
                note: metric.note
            )
        }
    }

    static func mergeUniqueBullets(_ lists: [[String]?]) -> [String] {
        var result: [String] = []
        for list in lists {
            guard let list else { continue }
            for raw in list {
                let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !item.isEmpty else { continue }
                if result.contains(where: { isSimilarBullet($0, item) }) { continue }
                result.append(item)
            }
        }
        return result
    }

    static func financialStrengths(
        strength: FinancialStrength?,
        overview: FundamentalsOverview? = nil
    ) -> [String] {
        _ = overview
        return mergeUniqueBullets([strength?.strengths])
    }

    static func financialRisks(
        strength: FinancialStrength?,
        overview: FundamentalsOverview? = nil
    ) -> [String] {
        _ = overview
        return mergeUniqueBullets([strength?.risks])
    }

    struct InvestmentThesis {
        let bullCase: [String]
        let bearCase: [String]
        let valuationSummary: String
    }

    static func investmentThesis(overview: FundamentalsOverview?) -> InvestmentThesis? {
        guard let overview else { return nil }
        let summary = overview.valuationSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if overview.investmentThesis.bullCase.isEmpty,
           overview.investmentThesis.bearCase.isEmpty,
           summary.isEmpty {
            return nil
        }
        return InvestmentThesis(
            bullCase: overview.investmentThesis.bullCase,
            bearCase: overview.investmentThesis.bearCase,
            valuationSummary: summary
        )
    }

    static func pickHighlightFilings(_ filings: [SecFilingSummary]) -> [SecFilingSummary] {
        let sorted = filings.sorted { lhs, rhs in
            filingSortKey(lhs.filingDate) > filingSortKey(rhs.filingDate)
        }
        return highlightFilingForms.compactMap { form in
            sorted.first { filing in
                filing.form == form || filing.form.hasPrefix("\(form)/")
            }
        }
    }

    private static func filingSortKey(_ value: String) -> TimeInterval {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: value)?.timeIntervalSince1970 ?? 0
    }

    private static func normalizeLabel(_ label: String) -> String {
        label.lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeBullet(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isSimilarBullet(_ a: String, _ b: String) -> Bool {
        let na = normalizeBullet(a)
        let nb = normalizeBullet(b)
        guard !na.isEmpty, !nb.isEmpty else { return false }
        if na == nb { return true }
        if na.count > 24, nb.count > 24 {
            return na.contains(nb) || nb.contains(na)
        }
        return false
    }

    private static func splitToBullets(_ text: String?, max: Int) -> [String] {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let parts = text
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: ". ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 12 }
        return Array(parts.prefix(max))
    }

    private static func truncateToSentences(_ text: String, max: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let pattern = #"[^.!?]+[.!?]+|[^.!?]+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return trimmed
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let matches = regex.matches(in: trimmed, range: range)
        let sentences = matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: trimmed) else { return nil }
            return String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return sentences.prefix(max).joined(separator: " ")
    }

    private static func filterAgainst(_ items: [String], excluded: [String]) -> [String] {
        guard !excluded.isEmpty else { return items }
        return items.filter { item in
            !excluded.contains(where: { isSimilarBullet($0, item) })
        }
    }
}
