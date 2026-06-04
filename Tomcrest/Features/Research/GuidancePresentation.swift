import Foundation

/// UI-only mapping from deterministic guidance API output (does not change scoring).
enum GuidancePresentation {
    private static let topDriversMax = 3
    private static let maxSupporting = 2
    private static let concentrationMinPct = 20.0
    private static let thetaMaxDTE = 21

    enum DriverCategory {
        case concentration, pnlAssignment, regime, technical, other
    }

    struct DedupedDriver {
        let label: String
        let points: Double
        let category: DriverCategory
        let semanticKey: String
        let portfolioLevel: Bool
    }

    struct PositionCopy {
        let mainReason: String?
        let supportingPoints: [String]
    }

    // MARK: - Public

    static func urgencyLabel(_ urgency: Int) -> String {
        if urgency >= 80 { return "Very high urgency" }
        if urgency >= 55 { return "High urgency" }
        if urgency >= 30 { return "Moderate urgency" }
        return "Low urgency"
    }

    static func symbolThesisLine(
        thesis: SymbolThesisBlock,
        positions: [PositionGuidanceItem]
    ) -> String {
        var parts = [thesisPhrase(thesis.thesis)]
        if let regimeId = thesis.regimeId, !hasRegimeContributor(positions) {
            parts.append(regimePhrase(regimeId))
        }
        if let score = thesis.tradeQualityScore, !hasTradeQualityContributor(positions) {
            parts.append(tradeQualityPhrase(score))
        }
        return parts.joined(separator: " · ")
    }

    static func buildDriverDisplay(
        positions: [PositionGuidanceItem]
    ) -> [String: [DedupedDriver]] {
        let ownership = buildPortfolioOwnership(positions)
        var result: [String: [DedupedDriver]] = [:]
        for item in positions {
            result[item.positionKey] = selectDrivers(item, all: positions, ownership: ownership)
        }
        return result
    }

    static func positionCopy(
        item: PositionGuidanceItem,
        drivers: [DedupedDriver]
    ) -> PositionCopy {
        let mapped = dedupeSentences(
            drivers.compactMap { plainEnglish(from: $0) }
        )
        guard let main = pickMainReason(item, drivers: drivers, mapped: mapped) else {
            return PositionCopy(mainReason: nil, supportingPoints: [])
        }
        let mainNorm = normalize(main)
        let supporting = dedupeSentences(mapped)
            .filter { normalize($0) != mainNorm }
            .prefix(maxSupporting)
        return PositionCopy(
            mainReason: main,
            supportingPoints: Array(supporting)
        )
    }

    static func contractLine(_ item: PositionGuidanceItem) -> String {
        if item.positionKind == .equityLong {
            let q = item.quantity
            let n = q.rounded() == q ? String(Int(q)) : String(q)
            let unit = q == 1 ? "share" : "shares"
            return "\(n) \(unit)"
        }
        if let paren = item.displayLabel.range(of: #"\([^)]*\)$"#, options: .regularExpression) {
            return String(item.displayLabel[..<paren.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return item.displayLabel
    }

    static func profitLossText(_ pct: Double?) -> String? {
        guard let pct else { return nil }
        let sign = pct >= 0 ? "+" : ""
        return String(format: "P/L %@%.1f%%", sign, pct)
    }

    // MARK: - Driver selection (mirrors web guidanceScoringContributors)

    private static func selectDrivers(
        _ item: PositionGuidanceItem,
        all: [PositionGuidanceItem],
        ownership: [String: String]
    ) -> [DedupedDriver] {
        let ranked = rankedContributors(item).filter { passesFilters($0, item: item, all: all) }
        let eligible = ranked.filter { c in
            let key = semanticKey(c)
            guard let owner = ownership[key] else { return true }
            return owner == item.positionKey
        }
        let pool = dedupe(eligible)
        var selected = Array(pool.prefix(topDriversMax))
        if item.positionKind == .equityLong {
            selected = enforceEquity(selected, pool: pool)
        } else {
            selected = enforceOptions(selected, pool: pool)
        }
        return sortByPoints(selected)
    }

    private static func rankedContributors(_ item: PositionGuidanceItem) -> [ScoringContributor] {
        if !item.effectiveScoringContributors.isEmpty {
            return item.effectiveScoringContributors.sorted { $0.points > $1.points }
        }
        var fallback: [ScoringContributor] = []
        for driver in [item.primaryDriver, item.secondaryDriver, item.tertiaryDriver].compactMap({ $0 }) {
            let label = (driver.detail?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? driver.label
            fallback.append(ScoringContributor(
                bucket: driver.code,
                points: driver.points,
                label: label,
                driverCode: driver.code
            ))
        }
        return fallback.sorted { $0.points > $1.points }
    }

    private static func buildPortfolioOwnership(_ positions: [PositionGuidanceItem]) -> [String: String] {
        var candidates: [String: [(key: String, item: PositionGuidanceItem, points: Double, kind: PositionKind)]] = [:]
        for item in positions {
            for c in rankedContributors(item).filter({ passesFilters($0, item: item, all: positions) }) {
                guard isPortfolioLevel(c) else { continue }
                let sk = semanticKey(c)
                candidates[sk, default: []].append((sk, item, c.points, item.positionKind))
            }
        }
        var ownership: [String: String] = [:]
        for (_, list) in candidates {
            let owner = pickOwner(list)
            for entry in list {
                ownership[entry.key] = owner.positionKey
            }
        }
        return ownership
    }

    private static func pickOwner(
        _ list: [(key: String, item: PositionGuidanceItem, points: Double, kind: PositionKind)]
    ) -> PositionGuidanceItem {
        let maxPts = list.map(\.points).max() ?? 0
        let tied = list.filter { $0.points == maxPts }
        if let equity = tied.first(where: { $0.kind == .equityLong }) {
            return equity.item
        }
        return tied.first!.item
    }

    // MARK: - Plain English

    private static func plainEnglish(from driver: DedupedDriver) -> String? {
        plainEnglishFromLabel(driver.label, category: driver.category, semanticKey: driver.semanticKey)
    }

    private static func plainEnglishFromLabel(
        _ raw: String,
        category: DriverCategory,
        semanticKey: String
    ) -> String? {
        let label = raw.lowercased()
        let key = semanticKey.uppercased()

        if label.contains("trade quality") || key == "TREND_DETERIORATION" {
            if label.contains("pressure") || label.contains("weak") {
                return "Technical conditions have weakened"
            }
            return "Technical and trade-quality signals are soft"
        }
        if category == .regime || label.contains("regime") || key == "UNFAVORABLE_REGIME" {
            if label.contains("neutral") || label.contains("chop") {
                return "Market regime is neutral"
            }
            if label.contains("bear") || label.contains("risk off") {
                return "Market backdrop is cautious"
            }
            if label.contains("bull") || label.contains("risk on") {
                return "Market backdrop is supportive"
            }
            return "Market regime is working against this position"
        }
        if label.contains("relative strength") || key == "WEAKENING_RELATIVE_STRENGTH" {
            return "The stock is lagging the broader market"
        }
        if label.contains("volume") || label.contains("momentum") {
            return "Momentum and volume trends have weakened"
        }
        if category == .concentration || label.contains("portfolio weight") {
            if label.contains("very high") || label.contains("elevated") {
                return "This position is a large part of your portfolio"
            }
            return "Position size adds portfolio risk"
        }
        if label.contains("unrealized loss") || label.contains("drawdown") || key == "LARGE_DRAWDOWN" {
            return nil
        }
        if label.contains("assignment") || key == "ASSIGNMENT_RISK" {
            return "Assignment risk is elevated"
        }
        if label.contains("expiration") || label.contains("days to expiration") || label.contains("theta") || key == "THETA_DECAY" {
            return "Time decay will continue to reduce option value"
        }
        if label.contains("thesis conflict") { return "Position conflicts with the symbol outlook" }
        if label.contains("earnings") { return "Earnings timing adds uncertainty" }
        if label.contains("alert") { return "Recent alerts flag added risk" }
        if label.contains("moneyness") { return "Strike distance affects outcome risk" }
        return nil
    }

    private static func profitLossMainReason(_ item: PositionGuidanceItem) -> String? {
        guard let pct = item.openProfitLossPct else { return nil }
        let subject = item.positionKind == .equityLong ? "stock" : "option"
        let absPct = abs(pct)
        let amount = absPct >= 10 ? String(Int(absPct.rounded())) : String(format: "%.1f", absPct)
        if pct <= -5 { return "The \(subject) is down ~\(amount)% from entry" }
        if pct >= 5 { return "The \(subject) is up ~\(amount)% from entry" }
        return "The \(subject) is near breakeven"
    }

    private static func pickMainReason(
        _ item: PositionGuidanceItem,
        drivers: [DedupedDriver],
        mapped: [String]
    ) -> String? {
        let top = drivers.first
        let pnl = profitLossMainReason(item)
        if top?.category == .pnlAssignment, let pnl { return pnl }
        if let pnl, top != nil, drivers.allSatisfy({ $0.category == .pnlAssignment }) { return pnl }
        if let first = mapped.first { return first }
        if let pnl, top?.category == .pnlAssignment || top == nil { return pnl }
        if let driver = item.primaryDriver,
           let mappedLabel = plainEnglishFromLabel(
               driver.detail ?? driver.label,
               category: categoryFromCode(driver.code),
               semanticKey: driver.code.uppercased()
           ) {
            return mappedLabel
        }
        return sanitize(item.primaryReason)
    }

    private static func sanitize(_ reason: String) -> String? {
        var text = reason
        if let range = text.range(of: #"^[^:]+:\s*"#, options: .regularExpression) {
            text = String(text[range.upperBound...])
        }
        text = text.replacingOccurrences(of: #"\d+(\.\d+)?%?"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "risk_on_chop", with: "choppy market", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "_", with: " ")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8 else { return nil }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    // MARK: - Helpers

    private static func thesisPhrase(_ thesis: SymbolThesis) -> String {
        switch thesis {
        case .bullish: "Overall outlook is bullish"
        case .neutral: "Overall outlook is neutral"
        case .bearish: "Overall outlook is bearish"
        }
    }

    private static func tradeQualityPhrase(_ score: Int) -> String {
        if score >= 60 { return "Trade setup looks favorable" }
        if score >= 40 { return "Trade setup is mixed" }
        return "Trade setup looks weak"
    }

    private static func regimePhrase(_ regimeId: String) -> String {
        let id = regimeId.lowercased()
        if id.contains("chop") { return "Market is choppy with no clear trend" }
        if id.contains("risk_on") { return "Market regime supports risk-taking" }
        if id.contains("risk_off") { return "Market regime favors caution" }
        return "Market regime is \(humanizeRegime(regimeId).lowercased())"
    }

    private static func humanizeRegime(_ id: String) -> String {
        id.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private static func hasRegimeContributor(_ positions: [PositionGuidanceItem]) -> Bool {
        positions.contains { item in
            rankedContributors(item).contains { category($0) == .regime }
        }
    }

    private static func hasTradeQualityContributor(_ positions: [PositionGuidanceItem]) -> Bool {
        positions.contains { item in
            rankedContributors(item).contains {
                $0.label.lowercased().contains("trade quality")
            }
        }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dedupeSentences(_ sentences: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for s in sentences {
            let key = normalize(s)
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            out.append(s)
        }
        return out
    }

    private static func sortByPoints(_ drivers: [DedupedDriver]) -> [DedupedDriver] {
        drivers.sorted { $0.points > $1.points }
    }

    private static func dedupe(_ contributors: [ScoringContributor]) -> [DedupedDriver] {
        var map: [String: DedupedDriver] = [:]
        for c in contributors {
            let label = c.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            let d = DedupedDriver(
                label: label,
                points: c.points,
                category: category(c),
                semanticKey: semanticKey(c),
                portfolioLevel: isPortfolioLevel(c)
            )
            if let existing = map[d.semanticKey] {
                if d.points > existing.points { map[d.semanticKey] = d }
            } else {
                map[d.semanticKey] = d
            }
        }
        return sortByPoints(Array(map.values))
    }

    private static func category(_ c: ScoringContributor) -> DriverCategory {
        let code = (c.driverCode ?? "").uppercased()
        let bucket = c.bucket.lowercased()
        let label = c.label.lowercased()
        if code == "EXCESSIVE_CONCENTRATION" || bucket == "concentration" || label.contains("portfolio weight") {
            return .concentration
        }
        if bucket == "unrealized_loss" || bucket == "assignment" || label.contains("assignment") || label.contains("unrealized loss") {
            return .pnlAssignment
        }
        if bucket == "regime" || label.contains("regime") { return .regime }
        if bucket == "technical" || bucket == "theta" || bucket == "relative_strength" || label.contains("trade quality") || label.contains("theta") {
            return .technical
        }
        return .other
    }

    private static func categoryFromCode(_ code: String) -> DriverCategory {
        category(ScoringContributor(bucket: code, points: 0, label: code, driverCode: code))
    }

    private static func semanticKey(_ c: ScoringContributor) -> String {
        if let code = c.driverCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
            return code.uppercased()
        }
        var head = c.label.lowercased().components(separatedBy: CharacterSet(charactersIn: "—–-")).first ?? c.label.lowercased()
        head = head.replacingOccurrences(of: #"\b\d+(\.\d+)?%?\b"#, with: "", options: .regularExpression)
        head = head.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return head.isEmpty ? c.bucket.lowercased() : head
    }

    private static func isPortfolioLevel(_ c: ScoringContributor) -> Bool {
        category(c) == .concentration || c.label.lowercased().contains("portfolio weight")
    }

    private static func passesFilters(
        _ c: ScoringContributor,
        item: PositionGuidanceItem,
        all: [PositionGuidanceItem]
    ) -> Bool {
        guard c.points > 0 else { return false }
        guard !c.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard isLegAppropriate(c, item: item, all: all) else { return false }
        if category(c) == .concentration, item.positionKind == .equityLong,
           let pct = concentrationPct(c.label), pct < concentrationMinPct {
            return false
        }
        if item.positionKind != .equityLong,
           c.bucket == "theta" || c.label.lowercased().contains("expiration"),
           let dte = daysToExpiration(item), dte > thetaMaxDTE {
            return false
        }
        return true
    }

    private static func isLegAppropriate(
        _ c: ScoringContributor,
        item: PositionGuidanceItem,
        all: [PositionGuidanceItem]
    ) -> Bool {
        let bucket = c.bucket.lowercased()
        let hasEquity = all.contains { $0.positionKind == .equityLong }
        let hasOption = all.contains { $0.positionKind != .equityLong }
        if item.positionKind == .equityLong {
            if ["theta", "assignment", "moneyness"].contains(bucket) { return false }
            let label = c.label.lowercased()
            if label.contains("assignment") || label.contains("theta") || label.contains("expiration") {
                return false
            }
        }
        if item.positionKind != .equityLong, hasEquity, hasOption {
            if ["regime", "technical", "relative_strength", "volume", "concentration"].contains(bucket) { return false }
            let label = c.label.lowercased()
            if label.contains("regime") || label.contains("trade quality") || label.contains("relative strength") {
                return false
            }
        }
        return true
    }

    private static func concentrationPct(_ label: String) -> Double? {
        guard let match = label.range(of: #"(\d+(?:\.\d+)?)\s*%"#, options: .regularExpression) else { return nil }
        let snippet = String(label[match])
        let digits = snippet.filter { "0123456789.".contains($0) }
        return Double(digits)
    }

    private static func daysToExpiration(_ item: PositionGuidanceItem) -> Int? {
        if let exp = item.expiration {
            let iso = exp.contains("T") ? exp : "\(exp)T00:00:00"
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var date = formatter.date(from: iso)
            if date == nil {
                formatter.formatOptions = [.withFullDate]
                date = formatter.date(from: exp)
            }
            if let date {
                return Calendar.current.dateComponents([.day], from: Date(), to: date).day
            }
        }
        if let match = item.displayLabel.range(of: #"^(\d+)d"#, options: .regularExpression) {
            let digits = item.displayLabel[match].filter(\.isNumber)
            return Int(digits)
        }
        return nil
    }

    private static func isEquityMacro(_ d: DedupedDriver) -> Bool {
        d.category == .regime || d.category == .technical
            || d.semanticKey.contains("relative strength")
            || d.label.lowercased().contains("relative strength")
    }

    private static func enforceEquity(_ selected: [DedupedDriver], pool: [DedupedDriver]) -> [DedupedDriver] {
        var out = sortByPoints(selected)
        if !out.isEmpty, out.allSatisfy({ $0.category == .concentration }) {
            if let fill = pool.first(where: isEquityMacro) {
                out = sortByPoints(out.filter { $0.category != .concentration } + [fill])
            } else {
                out = out.filter { $0.category != .concentration }
            }
        }
        if !out.contains(where: isEquityMacro), let fill = pool.first(where: isEquityMacro),
           !out.contains(where: { $0.semanticKey == fill.semanticKey }) {
            out = sortByPoints(out + [fill])
        }
        return Array(out.prefix(topDriversMax))
    }

    private static func enforceOptions(_ selected: [DedupedDriver], pool: [DedupedDriver]) -> [DedupedDriver] {
        var out = sortByPoints(selected)
        if !out.contains(where: { $0.category == .pnlAssignment }),
           let fill = pool.first(where: { $0.category == .pnlAssignment }),
           !out.contains(where: { $0.semanticKey == fill.semanticKey }) {
            out = sortByPoints(out + [fill])
        }
        return Array(out.prefix(topDriversMax))
    }
}
