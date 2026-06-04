import Foundation

enum MomentumBreakoutAlertsTab: String, CaseIterable {
    case active = "Active"
    case history = "History"
}

@MainActor
@Observable
final class MomentumBreakoutAlertsViewModel {
    private let auth: AuthSession

    var selectedTab: MomentumBreakoutAlertsTab = .active
    var activeAlerts: [MomentumBreakoutAlertDto] = []
    var historyAlerts: [MomentumBreakoutAlertDto] = []
    var disclaimer = ""
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var refreshWarnings: [String] = []
    var lastUpdated: Date?
    var paperMeta: PaperTradePerformanceMetaDto?
    var paperSummary: PaperTradeSummaryDto?
    var recentPaperOutcomes: [PaperTradeRecordDto] = []
    var paperPerformanceError: String?

    private var pollTask: Task<Void, Never>?

    init(auth: AuthSession) {
        self.auth = auth
    }

    var displayedAlerts: [MomentumBreakoutAlertDto] {
        selectedTab == .active ? activeAlerts : historyAlerts
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshActive(silent: true)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func loadAll() async {
        guard let token = accessToken else {
            errorMessage = "Sign in to view trade plan alerts."
            return
        }
        isLoading = activeAlerts.isEmpty && historyAlerts.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let active = MomentumBreakoutAlertService.fetchActiveAlerts(accessToken: token)
            async let history = MomentumBreakoutAlertService.fetchAlertHistory(accessToken: token)
            let activeResponse = try await active
            let historyResponse = try await history
            activeAlerts = activeResponse.alerts
            historyAlerts = historyResponse.alerts
            disclaimer = activeResponse.disclaimer
            lastUpdated = Date()
            await loadPaperPerformance(accessToken: token)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadPaperPerformance(accessToken: String) async {
        do {
            async let summaryRequest = MomentumBreakoutAlertService.fetchPaperPerformanceSummary(accessToken: accessToken)
            async let tradesRequest = MomentumBreakoutAlertService.fetchPaperPerformanceTrades(accessToken: accessToken)
            let summaryResponse = try await summaryRequest
            let tradesResponse = try await tradesRequest
            paperMeta = summaryResponse.meta
            self.paperSummary = summaryResponse.summary
            recentPaperOutcomes = tradesResponse.trades.filter {
                ["TARGET_HIT", "STOP_HIT", "EXPIRED"].contains($0.status)
            }
            paperPerformanceError = nil
        } catch {
            paperPerformanceError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refreshActive(silent: Bool = false) async {
        guard let token = accessToken else { return }
        if !silent { isLoading = activeAlerts.isEmpty }
        do {
            let response = try await MomentumBreakoutAlertService.fetchActiveAlerts(accessToken: token)
            activeAlerts = response.alerts
            if !response.disclaimer.isEmpty {
                disclaimer = response.disclaimer
            }
            lastUpdated = Date()
        } catch {
            if !silent {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
        if !silent { isLoading = false }
    }

    func manualRefresh() async {
        guard let token = accessToken else {
            errorMessage = "Sign in to view trade plan alerts."
            return
        }
        isRefreshing = true
        errorMessage = nil
        refreshWarnings = []
        defer { isRefreshing = false }
        do {
            let response = try await MomentumBreakoutAlertService.refreshAlerts(accessToken: token)
            activeAlerts = response.alerts
            disclaimer = response.disclaimer
            refreshWarnings = response.warnings
            lastUpdated = Date()
            let historyResponse = try await MomentumBreakoutAlertService.fetchAlertHistory(accessToken: token)
            historyAlerts = historyResponse.alerts
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var accessToken: String? {
        guard let token = auth.accessToken, !token.isEmpty else { return nil }
        return token
    }
}

@MainActor
@Observable
final class MomentumBreakoutNotificationsViewModel {
    private let auth: AuthSession

    var notifications: [MomentumBreakoutNotificationDto] = []
    var isLoading = false
    var errorMessage: String?

    init(auth: AuthSession) {
        self.auth = auth
    }

    var unreadCount: Int {
        notifications.filter { !$0.read }.count
    }

    func load(unreadOnly: Bool = false) async {
        guard let token = accessToken else { return }
        isLoading = notifications.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await MomentumBreakoutAlertService.fetchNotifications(
                accessToken: token,
                unreadOnly: unreadOnly
            )
            notifications = response.notifications
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func markRead(notificationId: String) async {
        guard let token = accessToken else { return }
        do {
            let response = try await MomentumBreakoutAlertService.markNotificationRead(
                accessToken: token,
                notificationId: notificationId
            )
            if let index = notifications.firstIndex(where: { $0.notificationId == notificationId }) {
                notifications[index] = response.notification
            }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var accessToken: String? {
        guard let token = auth.accessToken, !token.isEmpty else { return nil }
        return token
    }
}
