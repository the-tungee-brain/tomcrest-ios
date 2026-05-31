import Foundation

struct FundamentalMetricGroup: Identifiable {
    let id: String
    let title: String
    let metrics: [FundamentalMetric]
}

enum FundamentalMetricGroups {
    private static let stockGroups: [(id: String, title: String, labels: [String])] = [
        ("valuation", "Valuation", ["P/E (trailing)", "P/E (forward)", "Price / book", "EPS (trailing)", "EPS (forward)", "Beta"]),
        ("profitability", "Profitability", ["Gross margin", "Operating margin", "Profit margin", "Return on equity", "Return on assets"]),
        ("growth", "Growth", ["Revenue growth", "Earnings growth"]),
        ("balance-sheet", "Balance sheet & cash", ["Debt / equity", "Current ratio", "Free cash flow"]),
        ("income", "Income", ["Dividend yield", "Annual dividend per share", "Payout ratio"]),
    ]

    static func group(_ metrics: [FundamentalMetric]) -> [FundamentalMetricGroup] {
        guard !metrics.isEmpty else { return [] }

        let byLabel = Dictionary(uniqueKeysWithValues: metrics.map { ($0.label, $0) })
        var assigned = Set<String>()
        var groups: [FundamentalMetricGroup] = []

        for group in stockGroups {
            let groupMetrics = group.labels.compactMap { label -> FundamentalMetric? in
                guard let metric = byLabel[label], !assigned.contains(label) else { return nil }
                assigned.insert(label)
                return metric
            }
            if !groupMetrics.isEmpty {
                groups.append(FundamentalMetricGroup(id: group.id, title: group.title, metrics: groupMetrics))
            }
        }

        let remaining = metrics.filter { !assigned.contains($0.label) }
        if !remaining.isEmpty {
            groups.append(FundamentalMetricGroup(id: "other", title: "Other", metrics: remaining))
        }

        return groups
    }
}
