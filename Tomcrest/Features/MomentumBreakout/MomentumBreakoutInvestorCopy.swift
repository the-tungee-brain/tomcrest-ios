import Foundation

enum MomentumBreakoutInvestorCopy {
    static let watchlistSectionId = "mb-watchlist-section"
    static let rejectedPreviewCount = 3

    static func alertElementId(symbol: String) -> String {
        "mb-alert-\(symbol.uppercased())"
    }

    static let tradableMinProfitFactor = 1.2
    static let tradableMinTrades = 20
    static let tradableMaxStopDistancePct = 8.0

    enum MarketTone {
        case favorable
        case mixed
        case cautious
        case unknown
    }

    enum AlertVerdictKind: String {
        case approved = "Approved"
        case caution = "Caution"
        case rejected = "Rejected"
        case completed = "Completed"
    }

    struct HeroVerdict {
        let title: String
        let body: String
        let stocksScanned: Int
        let opportunitiesReviewed: Int
        let opportunitiesRejected: Int
        let opportunitiesApproved: Int
        let lastScanLabel: String?
        let tone: MarketTone
    }

    struct StrategyTrackRecord {
        let winRate: Double?
        let profitFactor: Double?
        let tradesStudied: Int?
    }

    struct AlertVerdict {
        let kind: AlertVerdictKind
        let explanation: String
    }

    static func isTradable(_ candidate: MomentumBreakoutScanCandidateDto) -> Bool {
        guard candidate.riskGate.allowed == true else { return false }
        guard let pf = candidate.historicalProfitFactor, pf >= tradableMinProfitFactor else {
            return false
        }
        guard let trades = candidate.historicalTotalTrades, trades >= tradableMinTrades else {
            return false
        }
        guard candidate.stopDistancePct <= tradableMaxStopDistancePct else { return false }
        return true
    }

    static func partition(_ scan: MomentumBreakoutScanResponse?) -> (
        tradable: [MomentumBreakoutScanCandidateDto],
        blocked: [MomentumBreakoutScanCandidateDto]
    ) {
        guard let scan else { return ([], []) }
        var tradable: [MomentumBreakoutScanCandidateDto] = []
        var blocked: [MomentumBreakoutScanCandidateDto] = []
        for candidate in scan.candidates {
            if isTradable(candidate) {
                tradable.append(candidate)
            } else {
                blocked.append(candidate)
            }
        }
        return (tradable, blocked)
    }

    static func marketTone(from scan: MomentumBreakoutScanResponse?) -> MarketTone {
        guard let scan, !scan.candidates.isEmpty else { return .unknown }
        var counts: [String: Int] = [:]
        for candidate in scan.candidates {
            let key = (candidate.marketRegime ?? "UNKNOWN").uppercased()
            counts[key, default: 0] += 1
        }
        let regime = counts.max(by: { $0.value < $1.value })?.key ?? "UNKNOWN"
        switch regime {
        case "RISK_ON", "BULL": return .favorable
        case "RISK_OFF", "BEAR": return .cautious
        default: return .mixed
        }
    }

    static func marketConditionsPhrase(_ tone: MarketTone) -> String {
        switch tone {
        case .favorable: return "supportive"
        case .cautious: return "cautious"
        case .mixed: return "mixed"
        case .unknown: return "unclear"
        }
    }

    static func formatScanTimestamp(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let date else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func buildHeroVerdict(
        scan: MomentumBreakoutScanResponse?,
        tradable: [MomentumBreakoutScanCandidateDto],
        blocked: [MomentumBreakoutScanCandidateDto],
        loading: Bool
    ) -> HeroVerdict {
        let tone = marketTone(from: scan)
        let conditions = marketConditionsPhrase(tone)

        if loading, scan == nil {
            return HeroVerdict(
                title: "Loading today's scan…",
                body: "We're checking the market for breakout opportunities.",
                stocksScanned: 0,
                opportunitiesReviewed: 0,
                opportunitiesRejected: 0,
                opportunitiesApproved: 0,
                lastScanLabel: nil,
                tone: .unknown
            )
        }

        guard let scan else {
            return HeroVerdict(
                title: "Today's scan unavailable",
                body: "We couldn't load the latest market scan. Try refreshing in a moment.",
                stocksScanned: 0,
                opportunitiesReviewed: 0,
                opportunitiesRejected: 0,
                opportunitiesApproved: 0,
                lastScanLabel: nil,
                tone: .unknown
            )
        }

        let reviewed = scan.validSetupsFound
        let rejectedCount = scan.blockedCandidatesCount > 0
            ? scan.blockedCandidatesCount
            : blocked.count
        let approved = tradable.count

        if approved > 0 {
            let noun = approved == 1 ? "Opportunity" : "Opportunities"
            return HeroVerdict(
                title: "\(approved) Trade \(noun) Today",
                body: "Market conditions are \(conditions). \(approved) breakout \(approved == 1 ? "opportunity passed" : "opportunities passed") our quality and risk requirements.",
                stocksScanned: scan.totalSymbolsScanned,
                opportunitiesReviewed: reviewed,
                opportunitiesRejected: rejectedCount,
                opportunitiesApproved: approved,
                lastScanLabel: formatScanTimestamp(scan.scanTime),
                tone: tone
            )
        }

        return HeroVerdict(
            title: "No Trade Opportunities Today",
            body: "Market conditions are \(conditions), but none of today's breakout opportunities passed our quality and risk requirements.",
            stocksScanned: scan.totalSymbolsScanned,
            opportunitiesReviewed: reviewed,
            opportunitiesRejected: rejectedCount,
            opportunitiesApproved: 0,
            lastScanLabel: formatScanTimestamp(scan.scanTime),
            tone: tone
        )
    }

    static func deriveStrategyTrackRecord(
        paperSummary: PaperTradeSummaryDto?,
        scan: MomentumBreakoutScanResponse?
    ) -> StrategyTrackRecord? {
        if let paperSummary, paperSummary.totalAlerts > 0 {
            return StrategyTrackRecord(
                winRate: paperSummary.winRate,
                profitFactor: paperSummary.profitFactor,
                tradesStudied: paperSummary.totalAlerts
            )
        }
        return deriveStrategyTrackRecordFromScan(scan)
    }

    private static func deriveStrategyTrackRecordFromScan(
        _ scan: MomentumBreakoutScanResponse?
    ) -> StrategyTrackRecord? {
        guard let scan, !scan.candidates.isEmpty else { return nil }
        var tradeWeight = 0
        var winSum = 0.0
        var pfSum = 0.0
        var pfWeight = 0
        for candidate in scan.candidates {
            let t = candidate.historicalTotalTrades ?? 0
            guard t > 0 else { continue }
            tradeWeight += t
            if let wr = candidate.historicalWinRate {
                let normalized = wr <= 1 ? wr : wr / 100
                winSum += normalized * Double(t)
            }
            if let pf = candidate.historicalProfitFactor {
                pfSum += pf * Double(t)
                pfWeight += t
            }
        }
        guard tradeWeight > 0 else { return nil }
        return StrategyTrackRecord(
            winRate: winSum > 0 ? winSum / Double(tradeWeight) : nil,
            profitFactor: pfWeight > 0 ? pfSum / Double(pfWeight) : nil,
            tradesStudied: tradeWeight
        )
    }

    static func rejectedReasons(for candidate: MomentumBreakoutScanCandidateDto) -> [String] {
        var reasons: [String] = []
        if candidate.riskGate.allowed != true {
            let filtered = MomentumBreakoutAlertPresentation.filteredRiskReasons(
                candidate.riskGate.reasons ?? []
            )
            for raw in filtered {
                if let plain = humanizeRiskReason(raw) {
                    reasons.append(plain)
                }
            }
            if reasons.isEmpty {
                reasons.append("Did not pass our safety checks.")
            }
        }
        if candidate.historicalProfitFactor == nil
            || (candidate.historicalProfitFactor ?? 0) < tradableMinProfitFactor {
            if let pf = candidate.historicalProfitFactor {
                reasons.append(String(format: "Historical performance was weak (PF %.2f)", pf))
            } else {
                reasons.append("Historical performance was weak (insufficient data)")
            }
        }
        if candidate.historicalTotalTrades == nil
            || (candidate.historicalTotalTrades ?? 0) < tradableMinTrades {
            reasons.append(
                "Not enough past examples on this stock (\(candidate.historicalTotalTrades ?? 0) studied, \(tradableMinTrades) required)"
            )
        }
        if candidate.stopDistancePct > tradableMaxStopDistancePct {
            reasons.append(
                String(format: "Stop distance was too wide (%.0f%%)", candidate.stopDistancePct)
            )
        }
        return Array(Set(reasons))
    }

    static func regimeLabel(_ regime: String?) -> String {
        switch (regime ?? "").uppercased() {
        case "RISK_ON", "BULL": return "Supportive trend"
        case "RISK_OFF", "BEAR": return "Cautious trend"
        case "NEUTRAL": return "Mixed trend"
        default: return "Trend unclear"
        }
    }

    static func deriveAlertVerdict(_ alert: MomentumBreakoutAlertDto) -> AlertVerdict {
        switch alert.lifecycleStatus {
        case .targetHit:
            return AlertVerdict(kind: .completed, explanation: "Target price was reached.")
        case .stopHit:
            return AlertVerdict(kind: .completed, explanation: "Stop price was reached.")
        case .expired:
            return AlertVerdict(kind: .completed, explanation: "This plan expired before completing.")
        case .cancelled:
            return AlertVerdict(kind: .completed, explanation: "You stopped tracking this plan.")
        default:
            break
        }

        let tone = MomentumBreakoutAlertPresentation.riskGateTone(action: alert.riskGateAction)
        let reasons = MomentumBreakoutAlertPresentation.filteredRiskReasons(alert.riskGateReasons ?? [])
            .map { MomentumBreakoutAlertPresentation.humanizeRiskReason($0) }

        switch tone {
        case .blocked:
            return AlertVerdict(
                kind: .rejected,
                explanation: reasons.first ?? "Did not pass our quality and safety requirements."
            )
        case .warning, .caution:
            return AlertVerdict(
                kind: .caution,
                explanation: reasons.first ?? "Passed core checks, but proceed carefully."
            )
        default:
            return AlertVerdict(kind: .approved, explanation: "Passed quality and risk checks.")
        }
    }

    private static func humanizeRiskReason(_ reason: String) -> String? {
        let lower = reason.lowercased()
        if lower.contains("neutral") {
            return "The broad market looks uncertain right now."
        }
        if lower.contains("max open positions") {
            return "You already have several similar plans being tracked."
        }
        if lower.contains("consecutive"), lower.contains("loss") {
            return "Recent similar plans finished with losses."
        }
        if lower.contains("drawdown") {
            return "Recent results for this strategy have been weak."
        }
        if lower.contains("volume") || lower.contains("climax") {
            return "Today's volume looks unusually high, which can be risky."
        }
        if lower.contains("mega") || lower.contains("correlation") {
            return "You may already have enough exposure to big tech names."
        }
        if lower.contains("circuit breaker") {
            return "Safety rules paused new alerts after a string of losses."
        }
        return nil
    }
}
