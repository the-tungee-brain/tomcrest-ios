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

struct ScoreBreakdownSegment: Identifiable, Sendable {
    let id: String
    let label: String
    let value: Double
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
}

enum TopMoversFormatting {
    static func rankingsHaveMlMetrics(_ items: [RankingItem]) -> Bool {
        items.contains { $0.mlProbability != nil || $0.expectedExcessReturn != nil }
    }

    static func topUniverseLabel(
        rank: Int,
        universeSize: Int?,
        listCount: Int
    ) -> String {
        let universe = universeSize ?? listCount
        guard universe > 0 else { return "Rank #\(rank)" }
        let topPct = Double(rank) / Double(universe) * 100
        if topPct <= 1 { return "Top 1% of universe" }
        if topPct <= 5 { return "Top 5% of universe" }
        if topPct <= 10 { return "Top 10% of universe" }
        if topPct <= 25 { return "Top 25% of universe" }
        return "Top \(Int(ceil(topPct)))% of universe"
    }

    static func signalStrengthLabel(scores: PatternIntelligenceScores?) -> String? {
        guard let scores else { return nil }
        let avg = (
            scores.relativeStrength
                + scores.trendStrength
                + scores.volumeConfirmation
                + scores.modelAlignment
                + scores.patternStrength
        ) / 5
        if avg >= 0.72 { return "Strong signal" }
        if avg >= 0.52 { return "Moderate signal" }
        return "Developing signal"
    }

    static func regimeNarrative(_ regimeId: String?) -> RegimeNarrative {
        let id = (regimeId ?? "").lowercased()
        switch id {
        case "risk_on_trend":
            return RegimeNarrative(
                title: "Risk-on · Trending market",
                guidance: "Momentum signals are active. Favor leaders with strong relative strength and volume confirmation."
            )
        case "risk_on_chop":
            return RegimeNarrative(
                title: "Risk-on · Choppy market",
                guidance: "Momentum signals are active, but expect more false breakouts. Be selective and wait for confirmation."
            )
        case "high_vol_chop":
            return RegimeNarrative(
                title: "High volatility · Choppy",
                guidance: "Larger swings and whipsaws. Reduce size and require stronger confirmation before acting."
            )
        case "risk_off":
            return RegimeNarrative(
                title: "Risk-off · Defensive",
                guidance: "Defensive posture. Prioritize quality and avoid aggressive breakout chasing."
            )
        default:
            return RegimeNarrative(
                title: regimeLabel(regimeId),
                guidance: "Rankings adapt to the current SPY trend and volatility regime."
            )
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

    /// Stable chip for list rows — does not change when pattern intelligence loads.
    static func trendDisplayForRow(rank: Int, listCount: Int) -> TrendDisplay {
        trendFromRank(rank: rank, listCount: listCount)
    }

    /// Price-trend readout for expanded detail (from pattern intelligence).
    static func trendDisplayFromIntelligence(_ intel: PatternIntelligenceResponse) -> TrendDisplay {
        let bias = intel.trendContext.trendBias.lowercased()
        let strength = intel.scores.trendStrength

        switch bias {
        case "uptrend":
            if strength >= 0.75 {
                return TrendDisplay(label: "Strong uptrend", glyph: "↗", tone: .positive)
            }
            if strength >= 0.55 {
                return TrendDisplay(label: "Uptrend", glyph: "↗", tone: .positive)
            }
            return TrendDisplay(label: "Mild uptrend", glyph: "↗", tone: .positive)
        case "downtrend":
            if strength <= 0.4 {
                return TrendDisplay(label: "Downtrend", glyph: "↘", tone: .negative)
            }
            return TrendDisplay(label: "Weak trend", glyph: "↘", tone: .negative)
        case "mixed":
            return TrendDisplay(label: "Sideways", glyph: "→", tone: .neutral)
        default:
            return TrendDisplay(label: "Trend unclear", glyph: "→", tone: .neutral)
        }
    }

    private static func trendFromRank(rank: Int, listCount: Int) -> TrendDisplay {
        let ratio = Double(rank) / Double(max(listCount, 1))
        if ratio <= 0.15 {
            return TrendDisplay(label: "Leader", glyph: "↗", tone: .positive)
        }
        if ratio >= 0.6 {
            return TrendDisplay(label: "Mixed", glyph: "→", tone: .neutral)
        }
        return TrendDisplay(label: "Rising", glyph: "↗", tone: .positive)
    }

    static func keySignals(from intel: PatternIntelligenceResponse?) -> [KeySignalItem] {
        guard let intel else { return [] }
        var items: [KeySignalItem] = []
        var seen = Set<String>()

        func add(id: String, label: String, positive: Bool = true) {
            guard !seen.contains(id) else { return }
            seen.insert(id)
            items.append(KeySignalItem(id: id, label: label, isPositive: positive))
        }

        let tc = intel.trendContext
        if tc.aboveSma50 == true { add(id: "sma50", label: "Above SMA50") }
        if tc.aboveSma200 == true { add(id: "sma200", label: "Above SMA200") }

        if let vol = tc.volRatio20d, vol >= 1.2 {
            add(id: "vol", label: String(format: "Relative volume %.1f×", vol))
        }

        if let rs = tc.rsVsSpy21d, rs > 0.02 {
            add(id: "rs21", label: "Strong relative strength")
        } else if intel.scores.relativeStrength >= 0.68 {
            add(id: "rs_score", label: "Strong relative strength")
        }

        if intel.scores.trendStrength >= 0.68 {
            add(id: "trend", label: "Strong trend alignment")
        }
        if intel.scores.volumeConfirmation >= 0.65 {
            add(id: "vol_confirm", label: "Volume confirming move")
        }

        for event in intel.chartIntelligence?.breakoutEvents ?? [] {
            let kind = (event.kind ?? event.label ?? "").lowercased()
            if kind.contains("high") || kind.contains("breakout") {
                add(id: "breakout", label: "Recent breakout / new high")
                break
            }
        }

        if let pattern = intel.primaryPattern {
            let bearish = pattern.direction.lowercased().contains("bear")
            add(id: "pattern", label: "\(pattern.label) pattern detected", positive: !bearish)
        }

        return Array(items.prefix(6))
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
            ScoreBreakdownSegment(
                id: key,
                label: label,
                value: min(1, max(0, raw))
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
