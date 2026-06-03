import Foundation

/// Product API v1 — decoded via `APIClient` snake_case strategy (no custom CodingKeys).
struct RankingsTopResponse: Codable, Sendable {
    let apiVersion: String
    let timestamp: String
    let runId: String
    let asOfDate: String
    let regimeId: String?
    let items: [RankingItem]
}

struct RankingItem: Codable, Identifiable, Hashable, Sendable {
    var id: String { symbol }
    let symbol: String
    let rank: Int
    let finalScore: Double
    let mlProbability: Double?
    let expectedExcessReturn: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        if let intRank = try? container.decode(Int.self, forKey: .rank) {
            rank = intRank
        } else {
            rank = Int(try container.decode(Double.self, forKey: .rank))
        }
        finalScore = try container.decode(Double.self, forKey: .finalScore)
        mlProbability = try container.decodeIfPresent(Double.self, forKey: .mlProbability)
        expectedExcessReturn = try container.decodeIfPresent(Double.self, forKey: .expectedExcessReturn)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(rank, forKey: .rank)
        try container.encode(finalScore, forKey: .finalScore)
        try container.encodeIfPresent(mlProbability, forKey: .mlProbability)
        try container.encodeIfPresent(expectedExcessReturn, forKey: .expectedExcessReturn)
    }

    private enum CodingKeys: String, CodingKey {
        case symbol, rank, finalScore, mlProbability, expectedExcessReturn
    }
}

struct SystemHealthResponse: Decodable, Sendable {
    let apiVersion: String
    let systemStatus: String
    let regimeId: String?
    let lastRankingRunAt: String?
    let universeSize: Int?
}

enum ContributionTier: String, Sendable {
    case strong
    case moderate
    case weak
    case missing
}

enum ConvictionTier: String, Sendable {
    case elite
    case strong
    case rising
    case mixed
}

struct ConvictionDisplay: Sendable {
    let tier: ConvictionTier
    let label: String
}

struct RankContext: Sendable {
    let rankLabel: String
    let subtitle: String
}

struct ScoreBreakdownSegment: Identifiable, Sendable {
    let id: String
    let label: String
    let value: Double
    let tier: ContributionTier
    let tierLabel: String
}

struct KeySignalItem: Identifiable, Sendable {
    let id: String
    let label: String
    let isPositive: Bool
}

struct TrendDisplay: Sendable {
    let label: String
    let glyph: String
    let tone: TopMoverTrendTone
}

struct RegimeNarrative: Sendable {
    let title: String
    let guidance: String
    let signalImpact: String
    let confidenceNote: String
}

struct InsightLine: Identifiable, Sendable {
    let id: String
    let label: String
}

struct StrengthsAndGaps: Sendable {
    let strengths: [InsightLine]
    let gaps: [InsightLine]
}

enum TopMoversFormatting {
    static func rankingsHaveMlMetrics(_ items: [RankingItem]) -> Bool {
        items.contains { $0.mlProbability != nil || $0.expectedExcessReturn != nil }
    }

    static func convictionLabel(_ tier: ConvictionTier) -> String {
        switch tier {
        case .elite: "Elite"
        case .strong: "Strong"
        case .rising: "Rising"
        case .mixed: "Mixed"
        }
    }

    static func convictionForRow(rank: Int, listCount: Int) -> ConvictionDisplay {
        let tier = TopMoversInsightEngine.convictionFromListPercentile(
            TopMoversInsightEngine.listRankPercentile(rank: rank, listCount: listCount)
        )
        return ConvictionDisplay(tier: tier, label: convictionLabel(tier))
    }

    static func convictionForDetail(
        rank: Int,
        listCount: Int,
        scores: PatternIntelligenceScores?
    ) -> ConvictionDisplay {
        let tier: ConvictionTier
        if let scores {
            tier = TopMoversInsightEngine.convictionFromSignalAverage(averageScore(scores))
        } else {
            tier = TopMoversInsightEngine.convictionFromListPercentile(
                TopMoversInsightEngine.listRankPercentile(rank: rank, listCount: listCount)
            )
        }
        return ConvictionDisplay(tier: tier, label: convictionLabel(tier))
    }

    static func rankContext(item: RankingItem, items: [RankingItem]) -> RankContext {
        TopMoversInsightEngine.rankContext(item: item, items: items)
    }

    static func regimeNarrative(_ regimeId: String?) -> RegimeNarrative {
        let id = (regimeId ?? "").lowercased()
        switch id {
        case "risk_on_trend":
            return RegimeNarrative(
                title: "Risk-on · Trending market",
                guidance: "Momentum signals are active. Favor leaders with strong relative strength and volume confirmation.",
                signalImpact: "Momentum signals historically perform well in this regime.",
                confidenceNote: "Signal confidence is generally elevated for trend leaders."
            )
        case "risk_on_chop":
            return RegimeNarrative(
                title: "Risk-on · Choppy market",
                guidance: "Momentum signals are active, but expect more false breakouts. Be selective and wait for confirmation.",
                signalImpact: "False breakouts are more common; confirmation matters more.",
                confidenceNote: "Treat conviction as one notch lower unless volume confirms."
            )
        case "high_vol_chop":
            return RegimeNarrative(
                title: "High volatility · Choppy",
                guidance: "Larger swings and whipsaws. Reduce size and require stronger confirmation before acting.",
                signalImpact: "Whipsaws can invalidate short-term momentum reads quickly.",
                confidenceNote: "Signal confidence is reduced — favor Elite/Strong only."
            )
        case "risk_off":
            return RegimeNarrative(
                title: "Risk-off · Defensive",
                guidance: "Defensive posture. Prioritize quality and avoid aggressive breakout chasing.",
                signalImpact: "Breakout and momentum signals underperform more often.",
                confidenceNote: "Downgrade discretionary conviction; focus on quality factors."
            )
        default:
            return RegimeNarrative(
                title: regimeLabel(regimeId),
                guidance: "Rankings adapt to the current SPY trend and volatility regime.",
                signalImpact: "Signal quality depends on the active regime.",
                confidenceNote: "Compare conviction and missing signals before acting."
            )
        }
    }

    private static func averageScore(_ scores: PatternIntelligenceScores) -> Double {
        (
            scores.relativeStrength
                + scores.trendStrength
                + scores.volumeConfirmation
                + scores.modelAlignment
                + scores.patternStrength
        ) / 5
    }

    static func contributionTier(for value: Double) -> ContributionTier {
        if value >= 0.68 { return .strong }
        if value >= 0.45 { return .moderate }
        if value >= 0.2 { return .weak }
        return .missing
    }

    static func contributionTierLabel(_ tier: ContributionTier) -> String {
        switch tier {
        case .strong: "Strong"
        case .moderate: "Moderate"
        case .weak: "Weak"
        case .missing: "Missing"
        }
    }

    static func showsContributionFill(tier: ContributionTier, value: Double) -> Bool {
        if tier == .missing || value < 0.08 { return false }
        return true
    }

    static func contributionBarWidth(tier: ContributionTier, value: Double) -> Double {
        guard showsContributionFill(tier: tier, value: value) else { return 0 }
        let clamped = min(1, max(0, value))
        let pct = clamped * 100
        switch tier {
        case .strong:
            return pct
        case .moderate:
            return max(pct, 10)
        case .weak:
            return max(pct, 14)
        case .missing:
            return 0
        }
    }

    static func regimeLabel(_ regimeId: String?) -> String {
        guard let regimeId, !regimeId.isEmpty else { return "Regime unknown" }
        return regimeId
            .split(separator: "_")
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    static func riskLabel(regimeId: String?) -> String {
        let lower = (regimeId ?? "").lowercased()
        if lower.contains("risk_off") { return "Risk-off" }
        if lower.contains("risk_on") || lower.contains("chop") || lower.contains("trend") {
            return "Risk-on"
        }
        return "Mixed"
    }

    static func probabilityText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    static func excessText(_ value: Double?) -> String {
        guard let value else { return "—" }
        let pct = value * 100
        let sign = pct >= 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, pct)
    }

    static func relativeTime(iso: String?) -> String {
        guard let iso, let date = parseISO8601(iso) else {
            return "Update time unknown"
        }
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "Updated just now" }
        if minutes < 60 { return "Updated \(minutes)m ago" }
        let hours = minutes / 60
        if hours < 48 { return "Updated \(hours)h ago" }
        return "Updated \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    static func priceTrendLabel(_ intel: PatternIntelligenceResponse?) -> String? {
        guard let intel else { return nil }
        switch intel.trendContext.trendBias.lowercased() {
        case "uptrend": return "Uptrend"
        case "downtrend": return "Downtrend"
        case "mixed": return "Sideways"
        default: return "Unclear"
        }
    }

    static func sparklineValues(from segments: [ScoreBreakdownSegment]) -> [Double] {
        let order = ["relative_strength", "trend", "volume", "breakout", "pattern"]
        return order.map { key in
            segments.first(where: { $0.id == key })?.value ?? 0
        }
    }

    private static let sparklineHeight: CGFloat = 22

    static func sparklineBarHeight(_ value: Double) -> CGFloat {
        let clamped = min(1, max(0, value))
        let tier = contributionTier(for: clamped)
        if !showsContributionFill(tier: tier, value: clamped) {
            return 4
        }
        let fromValue = CGFloat(clamped) * sparklineHeight
        switch tier {
        case .strong:
            return max(fromValue, 12)
        case .moderate:
            return max(fromValue, 10)
        case .weak:
            return max(fromValue, 9)
        case .missing:
            return 4
        }
    }

    static func sparklineBarTier(_ value: Double) -> ContributionTier {
        contributionTier(for: min(1, max(0, value)))
    }

    static func strengthsAndGaps(
        intel: PatternIntelligenceResponse?,
        segments: [ScoreBreakdownSegment]
    ) -> StrengthsAndGaps {
        var strengths: [InsightLine] = []
        var gaps: [InsightLine] = []
        var seenS = Set<String>()
        var seenG = Set<String>()
        var seenStrengthLabels = Set<String>()
        var seenGapLabels = Set<String>()

        func addStrength(_ id: String, _ label: String) {
            guard !seenS.contains(id), !seenStrengthLabels.contains(label) else { return }
            seenS.insert(id)
            seenStrengthLabels.insert(label)
            strengths.append(InsightLine(id: id, label: label))
        }
        func addGap(_ id: String, _ label: String) {
            guard !seenG.contains(id), !seenGapLabels.contains(label) else { return }
            seenG.insert(id)
            seenGapLabels.insert(label)
            gaps.append(InsightLine(id: id, label: label))
        }

        let strengthLabels: [String: String] = [
            "relative_strength": "Strong relative strength",
            "trend": "Trend alignment",
            "volume": "Volume confirmation",
            "breakout": "Breakout strength",
            "pattern": "Pattern confirmation",
        ]
        let gapLabels: [String: String] = [
            "relative_strength": "Relative strength could be stronger",
            "trend": "Trend alignment is only moderate",
            "volume": "Volume not fully confirming",
            "breakout": "Weak breakout component",
            "pattern": "No pattern confirmation",
        ]

        for seg in segments {
            switch seg.tier {
            case .strong:
                addStrength(seg.id, strengthLabels[seg.id] ?? seg.label)
            case .weak, .missing:
                addGap(seg.id, gapLabels[seg.id] ?? "Weak \(seg.label.lowercased())")
            case .moderate:
                break
            }
        }

        if let intel {
            if intel.trendContext.aboveSma50 == true { addStrength("sma50", "Above SMA50") }
            if intel.trendContext.aboveSma200 == true { addStrength("sma200", "Above SMA200") }

            let hasBreakout = (intel.chartIntelligence?.breakoutEvents ?? []).contains { event in
                let kind = (event.kind.isEmpty ? (event.label ?? "") : event.kind).lowercased()
                return kind.contains("high") || kind.contains("breakout")
            }
            if !hasBreakout {
                addGap("high", "Not near a recent high / breakout")
            }
        }

        return StrengthsAndGaps(
            strengths: Array(strengths.prefix(5)),
            gaps: Array(gaps.prefix(4))
        )
    }

    static func segments(from scores: PatternIntelligenceScores?) -> [ScoreBreakdownSegment] {
        guard let scores else { return [] }
        let pairs: [(String, String, Double)] = [
            ("relative_strength", "Relative strength", scores.relativeStrength),
            ("trend", "Trend", scores.trendStrength),
            ("volume", "Volume", scores.volumeConfirmation),
            ("breakout", "Breakout", scores.modelAlignment),
            ("pattern", "Pattern", scores.patternStrength),
        ]
        return pairs.map { key, label, raw in
            let value = min(1, max(0, raw))
            let tier = contributionTier(for: value)
            return ScoreBreakdownSegment(
                id: key,
                label: label,
                value: value,
                tier: tier,
                tierLabel: contributionTierLabel(tier)
            )
        }
    }

    private static func parseISO8601(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) { return date }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return fallback.date(from: iso)
    }
}

enum TopMoverTrendTone {
    case positive
    case neutral
    case negative
}
