import Foundation

enum SignalSeverity: String, Codable {
    case info
    case watch
    case warning
    case critical
}

struct IntelligenceSignal: Codable, Identifiable {
    var id: String { "\(kind)-\(message)" }
    let kind: String
    let severity: SignalSeverity
    let message: String
    let symbol: String?
}

struct ProactiveAlert: Codable, Identifiable {
    var id: String { action }
    let action: String
    let label: String
    let reason: String
    let priority: Int
    let symbol: String?
}

struct PortfolioIntelligence: Codable {
    let signals: [IntelligenceSignal]
    let digest: PortfolioDigest?
    let alerts: [ProactiveAlert]

    init(signals: [IntelligenceSignal], digest: PortfolioDigest? = nil, alerts: [ProactiveAlert]) {
        self.signals = signals
        self.digest = digest
        self.alerts = alerts
    }
}
