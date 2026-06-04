import SwiftUI

enum MomentumBreakoutStatusBadgeTone {
    case neutral
    case active
    case success
    case danger
    case muted
}

enum MomentumBreakoutRiskGateTone {
    case normal
    case warning
    case caution
    case blocked
}

enum MomentumBreakoutAlertPresentation {
    static func isCancellable(_ status: MomentumBreakoutLifecycleStatus) -> Bool {
        switch status {
        case .pendingEntry, .entryTriggered, .open:
            return true
        default:
            return false
        }
    }

    static func statusBadgeTone(for status: MomentumBreakoutLifecycleStatus) -> MomentumBreakoutStatusBadgeTone {
        switch status {
        case .pendingEntry:
            return .neutral
        case .entryTriggered, .open:
            return .active
        case .targetHit:
            return .success
        case .stopHit:
            return .danger
        case .expired, .cancelled, .unknown:
            return .muted
        }
    }

    static func statusLabel(for status: MomentumBreakoutLifecycleStatus) -> String {
        switch status {
        case .pendingEntry: "Waiting for buy price"
        case .entryTriggered: "Buy price reached"
        case .open: "Plan in progress"
        case .targetHit: "Target reached"
        case .stopHit: "Stop reached"
        case .expired: "Expired"
        case .cancelled: "Cancelled"
        case .unknown: "Unknown"
        }
    }

    static func statusBadgeColors(tone: MomentumBreakoutStatusBadgeTone) -> (background: Color, foreground: Color, border: Color) {
        switch tone {
        case .active:
            return (AppColors.accentMuted.opacity(0.45), AppColors.accentHighlight, AppColors.accentHighlight.opacity(0.35))
        case .success:
            return (AppColors.success.opacity(0.12), AppColors.success, AppColors.success.opacity(0.35))
        case .danger:
            return (AppColors.error.opacity(0.12), AppColors.error, AppColors.error.opacity(0.35))
        case .muted:
            return (AppColors.insetSurface, AppColors.tertiaryLabel, AppColors.separator)
        case .neutral:
            return (AppColors.secondaryFill, AppColors.secondaryLabel, AppColors.separator)
        }
    }

    static func riskGateTone(action: String?) -> MomentumBreakoutRiskGateTone {
        switch (action ?? "").uppercased() {
        case "WARN": return .warning
        case "SIZE_DOWN": return .caution
        case "BLOCK": return .blocked
        default: return .normal
        }
    }

    static func riskGateTitle(tone: MomentumBreakoutRiskGateTone) -> String {
        switch tone {
        case .warning: "Heads up"
        case .caution: "Consider a smaller position"
        case .blocked: "Not recommended right now"
        case .normal: "Passed safety checks"
        }
    }

    static func humanizeRiskReason(_ reason: String) -> String {
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
        return reason
    }

    static func riskGatePanelStyle(tone: MomentumBreakoutRiskGateTone) -> (background: Color, border: Color, foreground: Color) {
        switch tone {
        case .warning:
            return (Color.orange.opacity(0.12), Color.orange.opacity(0.35), Color.orange)
        case .caution:
            return (Color.orange.opacity(0.1), Color.orange.opacity(0.3), Color.orange)
        case .blocked:
            return (AppColors.error.opacity(0.12), AppColors.error.opacity(0.35), AppColors.error)
        case .normal:
            return (AppColors.insetSurface, AppColors.separator, AppColors.secondaryLabel)
        }
    }

    static func filteredRiskReasons(_ reasons: [String]) -> [String] {
        reasons.filter { reason in
            let lower = reason.lowercased()
            return !lower.contains("not investment advice")
                && !lower.contains("educational")
                && !lower.contains("no orders are placed")
        }
    }

    static func formatSetupName(_ setupName: String) -> String {
        setupName
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    static func formatUsd(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    static func formatWinRate(_ value: Double?) -> String {
        guard let value else { return "—" }
        let pct = value <= 1 ? value * 100 : value
        return String(format: "%.1f%%", pct)
    }

    static func formatProfitFactor(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    static func formatRiskReward(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2fR", value)
    }

    static func formatPct(_ value: Double?) -> String {
        guard let value else { return "—" }
        let pct = abs(value) <= 1 ? value * 100 : value
        return String(format: "%.1f%%", pct)
    }

    static func formatRatio(_ value: Double?) -> String {
        guard let value else { return "—" }
        if !value.isFinite { return "∞" }
        return String(format: "%.2f", value)
    }
}
