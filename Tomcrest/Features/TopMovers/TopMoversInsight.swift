import Foundation

struct RegimeCompact: Sendable {
    let title: String
    let impact: String
}

struct DecisionSummary: Sendable {
    let headline: String
    let reasons: [String]
}

struct MoverResearchInsight: Sendable {
    let thesis: String
    let supports: [InsightLine]
    let missing: [InsightLine]
    let confirmations: [InsightLine]
    let decisionSummary: DecisionSummary
    let regimeCompact: RegimeCompact
    let portfolioRole: String?
}

enum TopMoversInsightEngine {
    static let convictionFrameworkList = """
    List badge (today's rankings): ≥90th percentile Elite, ≥70th Strong, ≥45th Rising, else Mixed.
    """
    static let convictionFrameworkSignal = """
    Signal badge (detail): composite score ≥78% Elite, ≥62% Strong, ≥48% Rising, else Mixed.
    """

    static func listRankPercentile(rank: Int, listCount: Int) -> Int {
        let count = max(listCount, 1)
        return Int((1.0 - Double(rank - 1) / Double(count)) * 100.0)
    }

    static func convictionFromListPercentile(_ percentile: Int) -> ConvictionTier {
        if percentile >= 90 { return .elite }
        if percentile >= 70 { return .strong }
        if percentile >= 45 { return .rising }
        return .mixed
    }

    static func convictionFromSignalAverage(_ avg: Double) -> ConvictionTier {
        let pct = avg * 100
        if pct >= 78 { return .elite }
        if pct >= 62 { return .strong }
        if pct >= 48 { return .rising }
        return .mixed
    }

    static func rankContext(item: RankingItem, items: [RankingItem]) -> RankContext {
        if item.rank == 1 {
            return RankContext(rankLabel: "#1", subtitle: "Top pick today")
        }
        let leader = items.first(where: { $0.rank == 1 }) ?? items.first
        guard let leader, leader.finalScore > 0 else {
            return RankContext(rankLabel: "#\(item.rank)", subtitle: "In today's leaders")
        }
        let ratio = min(1, item.finalScore / leader.finalScore)
        let pct = Int((ratio * 100).rounded())
        let label: String
        if ratio >= 0.97 { label = "Close contender" }
        else if ratio >= 0.88 { label = "Competitive" }
        else if ratio >= 0.75 { label = "Trailing leader" }
        else { label = "Building vs leader" }
        return RankContext(
            rankLabel: "#\(item.rank)",
            subtitle: "\(label) · \(pct)% of leader strength"
        )
    }

    static func regimeCompact(regimeId: String?) -> RegimeCompact {
        let narrative = TopMoversFormatting.regimeNarrative(regimeId)
        let id = (regimeId ?? "").lowercased()
        var impact = narrative.signalImpact
        if id.contains("chop") {
            impact = "Confirmation matters more than usual."
        } else if id.contains("risk_off") {
            impact = "Momentum signals are less reliable."
        } else if id.contains("high_vol") {
            impact = "Whipsaw risk is elevated — require strong confirmation."
        } else if id == "risk_on_trend" {
            impact = "Momentum signals historically perform well."
        }
        return RegimeCompact(title: narrative.title, impact: impact)
    }

    static func portfolioRole(
        item: RankingItem,
        listCount: Int,
        inPortfolio: Bool,
        listTier: ConvictionTier,
        regimeId: String?
    ) -> String? {
        let regime = (regimeId ?? "").lowercased()
        if inPortfolio, item.rank <= 3 { return "Core momentum holding" }
        if inPortfolio { return "Held in model portfolio" }
        if item.rank <= 3, listTier == .elite || listTier == .strong {
            return "Prime portfolio candidate"
        }
        if item.rank <= 8, listTier != .mixed { return "Watchlist candidate" }
        if regime.contains("risk_off") { return "Defensive research only" }
        if regime.contains("chop"), item.rank > 5 { return "Satellite opportunity — confirm first" }
        if item.rank <= listCount / 2 { return "Research candidate" }
        return nil
    }

    static func build(
        item: RankingItem,
        intel: PatternIntelligenceResponse?,
        segments: [ScoreBreakdownSegment],
        regimeId: String?,
        listCount: Int,
        inPortfolio: Bool
    ) -> MoverResearchInsight {
        let sym = item.symbol.uppercased()
        let parsed = TopMoversFormatting.strengthsAndGaps(intel: intel, segments: segments)
        let listTier = convictionFromListPercentile(
            listRankPercentile(rank: item.rank, listCount: listCount)
        )
        let patternLabel = intel?.primaryPattern?.label

        let supports = Array(parsed.strengths.prefix(5))
        var missing = Array(parsed.gaps.prefix(4))
        if let regimeLine = regimeMissingLine(regimeId: regimeId) {
            missing.append(InsightLine(id: "regime", label: regimeLine))
        }

        let confirmations = confirmationsToWatch(
            intel: intel,
            segments: segments,
            gaps: parsed.gaps
        )

        return MoverResearchInsight(
            thesis: buildThesis(
                sym: sym,
                rank: item.rank,
                listCount: listCount,
                strengths: parsed.strengths,
                gaps: parsed.gaps,
                segments: segments,
                patternLabel: patternLabel,
                intel: intel
            ),
            supports: supports,
            missing: Array(missing.prefix(5)),
            confirmations: Array(confirmations.prefix(4)),
            decisionSummary: buildDecisionSummary(
                listTier: listTier,
                supports: supports,
                confirmations: confirmations,
                gaps: parsed.gaps
            ),
            regimeCompact: regimeCompact(regimeId: regimeId),
            portfolioRole: portfolioRole(
                item: item,
                listCount: listCount,
                inPortfolio: inPortfolio,
                listTier: listTier,
                regimeId: regimeId
            )
        )
    }

    private static func joinNatural(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default:
            return "\(items.dropLast().joined(separator: ", ")), and \(items.last!)"
        }
    }

    private static func rankPositionPhrase(rank: Int, listCount: Int) -> String {
        if rank == 1 { return "at the top of today's universe" }
        let pct = listRankPercentile(rank: rank, listCount: listCount)
        if pct >= 90 { return "near the top of the universe" }
        if pct >= 70 { return "among today's leading setups" }
        if pct >= 45 { return "in the upper tier of today's list" }
        return "at #\(rank) on today's list"
    }

    private static func supportVerb(_ count: Int) -> String {
        if count >= 3 { return "are all strong" }
        if count == 2 { return "are both supportive" }
        return "is the stand-out input"
    }

    private static func factorPhrasesForThesis(
        strengths: [InsightLine],
        segments: [ScoreBreakdownSegment],
        patternLabel: String?,
        intel: PatternIntelligenceResponse?
    ) -> [String] {
        var phrases = strengths.prefix(3).map { softenForReason($0.label) }

        if phrases.isEmpty {
            let ordered = segments.sorted { $0.value > $1.value }
            for seg in ordered where seg.tier == .strong || seg.tier == .moderate {
                phrases.append(softenForReason(seg.label))
                if phrases.count >= 3 { break }
            }
        }

        if let patternLabel, !patternLabel.isEmpty,
           (intel?.scores.patternStrength ?? 0) >= 0.55,
           !phrases.contains(where: { $0.contains("pattern") }) {
            phrases.append("\(patternLabel.lowercased()) pattern support")
        }

        return Array(phrases.prefix(3))
    }

    private static func missingPiecePhrase(_ gap: InsightLine) -> String {
        let id = gap.id
        if id.contains("pattern") { return "pattern confirmation" }
        if id.contains("breakout") || id == "high" { return "breakout confirmation" }
        if id.contains("vol") { return "volume confirmation" }
        if id.contains("trend") { return "trend alignment" }
        if id.contains("relative") { return "relative strength versus the market" }
        if id == "sma50" { return "a sustained hold above SMA50" }
        return softenForReason(gap.label)
            .replacingOccurrences(of: "^no ", with: "", options: .regularExpression)
    }

    private static func weakestFactorPhrase(
        segments: [ScoreBreakdownSegment]
    ) -> String? {
        let weak = segments
            .filter { $0.tier == .weak || $0.tier == .missing }
            .sorted { $0.value < $1.value }
        guard let seg = weak.first else { return nil }

        let byKey: [String: String] = [
            "pattern": "pattern confirmation",
            "breakout": "breakout confirmation",
            "volume": "volume confirmation",
            "trend": "trend alignment",
            "relative_strength": "relative strength versus the market"
        ]
        return byKey[seg.id] ?? "confirmation on \(seg.label.lowercased())"
    }

    private static func strengthenFurtherNeeds(
        gaps: [InsightLine],
        confirmations: [InsightLine],
        segments: [ScoreBreakdownSegment]
    ) -> [String] {
        var needs: [String] = []
        var seen = Set<String>()

        func add(_ phrase: String) {
            guard !seen.contains(phrase) else { return }
            seen.insert(phrase)
            needs.append(phrase)
        }

        for gap in gaps where gap.id != "regime" {
            if gap.id.contains("pattern") { add("bullish pattern signal") }
            else if gap.id.contains("breakout") || gap.id == "high" { add("confirmed breakout") }
            else if gap.id.contains("vol") { add("stronger volume confirmation") }
            else if gap.id.contains("trend") { add("sustained trend alignment") }
            else if gap.id == "sma50" { add("hold above SMA50") }
        }

        if needs.isEmpty {
            for watch in confirmations.prefix(2) {
                let lower = watch.label.lowercased()
                if lower.contains("breakout") || lower.contains("high") { add("confirmed breakout") }
                else if lower.contains("pattern") { add("bullish pattern signal") }
                else if lower.contains("volume") { add("stronger volume confirmation") }
                else if lower.contains("sma50") { add("hold above SMA50") }
            }
        }

        if needs.isEmpty, let weak = weakestFactorPhrase(segments: segments) {
            if weak == "pattern confirmation" { add("bullish pattern signal") }
            else if weak == "breakout confirmation" { add("confirmed breakout") }
            else if weak.contains("volume") { add("stronger volume confirmation") }
            else if weak.contains("trend") { add("sustained trend alignment") }
        }

        return Array(needs.prefix(2))
    }

    private static func formatStrengthenNeeds(_ needs: [String]) -> String {
        let withArticle = needs.map { $0.hasPrefix("a ") ? $0 : "a \($0)" }
        if withArticle.count >= 2 {
            let second = withArticle[1].replacingOccurrences(of: "^a ", with: "", options: .regularExpression)
            return "\(withArticle[0]) or \(second)"
        }
        if let first = withArticle.first { return first }
        return "follow-through on the next session"
    }

    private static func buildStrengthenSentence(
        rank: Int,
        listCount: Int,
        factors: [String],
        gaps: [InsightLine],
        confirmations: [InsightLine],
        segments: [ScoreBreakdownSegment]
    ) -> String {
        let needs = strengthenFurtherNeeds(gaps: gaps, confirmations: confirmations, segments: segments)
        let formatted = formatStrengthenNeeds(needs)
        let favorable = listRankPercentile(rank: rank, listCount: listCount) >= 70 && factors.count >= 2

        if favorable {
            return "Momentum remains favorable, but the setup would strengthen further with \(formatted)."
        }
        return "The setup would strengthen further with \(formatted)."
    }

    private static func buildThesis(
        sym: String,
        rank: Int,
        listCount: Int,
        strengths: [InsightLine],
        gaps: [InsightLine],
        segments: [ScoreBreakdownSegment],
        patternLabel: String?,
        intel: PatternIntelligenceResponse?
    ) -> String {
        let factors = factorPhrasesForThesis(
            strengths: strengths,
            segments: segments,
            patternLabel: patternLabel,
            intel: intel
        )
        let position = rankPositionPhrase(rank: rank, listCount: listCount)
        var sentences: [String] = []

        if !factors.isEmpty {
            sentences.append(
                "\(sym) ranks \(position) because \(joinNatural(factors)) \(supportVerb(factors.count))."
            )
        } else {
            sentences.append(
                "\(sym) ranks \(position) on today's composite momentum screen."
            )
        }

        let signalGaps = gaps.filter { $0.id != "regime" }
        let missing: String? = signalGaps.first.map { missingPiecePhrase($0) }
            ?? weakestFactorPhrase(segments: segments)

        if let missing {
            sentences.append("The primary missing piece is \(missing).")
        }

        let confirmations = confirmationsToWatch(
            intel: intel,
            segments: segments,
            gaps: gaps
        )
        sentences.append(
            buildStrengthenSentence(
                rank: rank,
                listCount: listCount,
                factors: factors,
                gaps: gaps,
                confirmations: confirmations,
                segments: segments
            )
        )

        return sentences.prefix(4).joined(separator: " ")
    }

    private static func softenForReason(_ label: String) -> String {
        label
            .replacingOccurrences(of: "^Strong ", with: "", options: .regularExpression)
            .replacingOccurrences(of: "Trend alignment", with: "trend alignment")
            .replacingOccurrences(of: "Volume confirmation", with: "volume confirmation")
            .replacingOccurrences(of: "Pattern confirmation", with: "pattern confirmation")
            .lowercased()
    }

    private static func capitalizeReason(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return first.uppercased() + trimmed.dropFirst()
    }

    private static func buildDecisionSummary(
        listTier: ConvictionTier,
        supports: [InsightLine],
        confirmations: [InsightLine],
        gaps: [InsightLine]
    ) -> DecisionSummary {
        let headline: String
        switch listTier {
        case .elite, .strong:
            headline = "Worth investigating today"
        case .rising:
            headline = "Worth a look if confirmations develop"
        case .mixed:
            headline = "Lower priority today"
        }

        var reasons: [String] = []
        if supports.count >= 2 {
            reasons.append(
                "\(softenForReason(supports[0].label)) and \(softenForReason(supports[1].label))."
            )
        } else if let first = supports.first {
            reasons.append("\(softenForReason(first.label)).")
        }

        if let watch = confirmations.first {
            let lower = watch.label.lowercased()
            reasons.append(lower.hasPrefix("await") ? lower : "Await \(lower).")
        } else if let gap = gaps.first {
            reasons.append(gap.label.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
        }

        if reasons.isEmpty {
            reasons.append("Review contribution bars before acting.")
        }

        return DecisionSummary(
            headline: headline,
            reasons: Array(reasons.prefix(2)).map { capitalizeReason($0) }
        )
    }

    private static func regimeMissingLine(regimeId: String?) -> String? {
        let id = (regimeId ?? "").lowercased()
        if id.contains("chop") { return "Choppy market regime" }
        if id.contains("risk_off") { return "Risk-off market regime" }
        if id.contains("high_vol") { return "High-volatility regime" }
        return nil
    }

    private static func confirmationsToWatch(
        intel: PatternIntelligenceResponse?,
        segments: [ScoreBreakdownSegment],
        gaps: [InsightLine]
    ) -> [InsightLine] {
        var items: [InsightLine] = []
        var seen = Set<String>()

        func add(_ id: String, _ label: String) {
            guard !seen.contains(id) else { return }
            seen.insert(id)
            items.append(InsightLine(id: id, label: label))
        }

        for gap in gaps {
            if gap.id.contains("breakout") || gap.id == "high" {
                add("breakout", "Break above recent high")
                add("high20", "New 20-day high")
            }
            if gap.id.contains("vol") { add("vol15", "Relative volume above 1.5×") }
            if gap.id.contains("pattern") { add("pattern", "Pattern confirmation on next session") }
            if gap.id.contains("trend") { add("trend", "Hold trend alignment vs SPY") }
            if gap.id.contains("relative") || gap.id.contains("rs") {
                add("rs", "Sustain relative strength vs SPY")
            }
        }

        if intel?.trendContext.aboveSma50 == false {
            add("sma50", "Reclaim and hold above SMA50")
        }
        if let vol = intel?.trendContext.volRatio20d, vol < 1.5 {
            add("vol15b", "Relative volume above 1.5×")
        }

        if let breakout = segments.first(where: { $0.id == "breakout" }),
           breakout.tier != .strong {
            add("breakout2", "Break above recent high")
        }

        return items
    }
}
