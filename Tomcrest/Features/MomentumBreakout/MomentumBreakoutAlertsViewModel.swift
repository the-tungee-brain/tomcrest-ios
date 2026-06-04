import Foundation

enum MomentumBreakoutAlertsTab: String, CaseIterable {
    case active = "Active Alerts"
    case history = "Completed Alerts"
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
    var cancellingAlertId: String?
    var errorMessage: String?
    var refreshWarnings: [String] = []
    var lastUpdated: Date?
    var paperMeta: PaperTradePerformanceMetaDto?
    var paperSummary: PaperTradeSummaryDto?
    var recentPaperOutcomes: [PaperTradeRecordDto] = []
    var paperPerformanceError: String?
    var scanSummary: MomentumBreakoutScanResponse?
    var scanLoading = false
    var scanErrorMessage: String?
    var watchlistHighlight = false
    var scrollToToken = 0
    var scrollAnchorId = MomentumBreakoutInvestorCopy.watchlistSectionId
    var featureFlags = MomentumBreakoutFeatureFlagsDto(
        alertsEnabled: true,
        alertCreationEnabled: true,
        alertNotificationsEnabled: true,
        paperAnalyticsEnabled: true
    )

    var stockCheckQuery = ""
    private(set) var stockCheckResults: [TickerSymbolItem] = []
    private(set) var stockCheckSearching = false
    var stockCheckResult: MomentumBreakoutCheckResponse?
    var stockCheckError: String?
    var stockCheckLoading = false
    var customPlan: CustomTradePlanResponse?
    var customPlanLoading = false
    var trackingSymbol: String?

    private var pollTask: Task<Void, Never>?
    private var stockCheckSearchTask: Task<Void, Never>?

    init(auth: AuthSession) {
        self.auth = auth
    }

    var displayedAlerts: [MomentumBreakoutAlertDto] {
        selectedTab == .active ? activeAlerts : historyAlerts
    }

    var trackedSymbols: Set<String> {
        Set(activeAlerts.map { $0.symbol.uppercased() })
    }

    func trackPlan(symbol: String) async {
        guard let token = accessToken else {
            errorMessage = "Sign in to track trade plan alerts."
            return
        }
        guard featureFlags.alertCreationEnabled else {
            stockCheckError = "Alert creation is temporarily unavailable."
            return
        }

        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty else { return }

        trackingSymbol = upper
        stockCheckError = nil
        errorMessage = nil
        defer { trackingSymbol = nil }

        do {
            let response = try await MomentumBreakoutAlertService.postTradePlanAlert(
                symbol: upper,
                accessToken: token
            )
            if !response.planAvailable {
                stockCheckError =
                    "We could not save this educational plan. It may not pass current safety rules."
                return
            }
            await refreshActive(silent: true)
            let historyResponse = try await MomentumBreakoutAlertService.fetchAlertHistory(
                accessToken: token
            )
            historyAlerts = historyResponse.alerts
            scrollToTrackedPlan(symbol: upper)
        } catch {
            let message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            stockCheckError = message
            errorMessage = message
        }
    }

    func scrollToTrackedPlan(symbol: String) {
        selectedTab = .active
        let upper = symbol.uppercased()
        if activeAlerts.contains(where: { $0.symbol.uppercased() == upper }) {
            scrollAnchorId = MomentumBreakoutInvestorCopy.alertElementId(symbol: upper)
        } else {
            scrollAnchorId = MomentumBreakoutInvestorCopy.watchlistSectionId
        }
        watchlistHighlight = true
        scrollToToken += 1
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            await MainActor.run {
                self?.watchlistHighlight = false
            }
        }
    }

    func updateStockCheckQuery(_ text: String) {
        stockCheckSearchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            stockCheckResults = []
            stockCheckSearching = false
            return
        }

        stockCheckSearchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            await self.performStockCheckSearch(trimmed)
        }
    }

    func runStockCheck(symbol: String) async {
        guard let token = accessToken else {
            stockCheckError = "Sign in to check symbols."
            return
        }
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty else {
            stockCheckError = "Search for a ticker or company name to check."
            return
        }

        stockCheckQuery = upper
        stockCheckResults = []
        stockCheckSearching = false
        stockCheckLoading = true
        stockCheckError = nil
        stockCheckResult = nil
        customPlan = nil
        defer { stockCheckLoading = false }

        do {
            stockCheckResult = try await MomentumBreakoutAlertService.fetchCheck(
                symbol: upper,
                accessToken: token
            )
            stockCheckQuery = stockCheckResult?.symbol ?? upper
        } catch {
            stockCheckResult = nil
            stockCheckError = Self.userFacingAPIError(error)
        }
    }

    func generateCustomPlan() async {
        guard let token = accessToken else { return }
        let sym = (stockCheckResult?.symbol ?? stockCheckQuery)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !sym.isEmpty else { return }

        customPlanLoading = true
        stockCheckError = nil
        defer { customPlanLoading = false }

        do {
            customPlan = try await MomentumBreakoutAlertService.postCustomTradePlan(
                symbol: sym,
                accessToken: token
            )
        } catch {
            customPlan = nil
            stockCheckError = Self.userFacingAPIError(error)
        }
    }

    private static func userFacingAPIError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case let .httpStatus(404, message):
                if let message, !message.isEmpty { return message }
                return "We don't have market data for this symbol yet."
            case let .httpStatus(code, message) where code >= 500:
                return message ?? "Server error. Try again in a moment."
            default:
                return apiError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private func performStockCheckSearch(_ keyword: String) async {
        guard let token = accessToken else {
            stockCheckResults = []
            stockCheckSearching = false
            return
        }
        stockCheckSearching = true
        do {
            let items = try await ResearchService.searchSymbols(
                query: keyword,
                accessToken: token
            )
            guard !Task.isCancelled else { return }
            stockCheckResults = items
        } catch {
            guard !Task.isCancelled else { return }
            stockCheckResults = []
        }
        stockCheckSearching = false
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
            let statusResponse = try await MomentumBreakoutAlertService.fetchFeatureStatus(
                accessToken: token
            )
            featureFlags = statusResponse.flags
            guard statusResponse.flags.alertsEnabled else {
                activeAlerts = []
                historyAlerts = []
                errorMessage = nil
                return
            }
            async let active = MomentumBreakoutAlertService.fetchActiveAlerts(accessToken: token)
            async let history = MomentumBreakoutAlertService.fetchAlertHistory(accessToken: token)
            let activeResponse = try await active
            let historyResponse = try await history
            activeAlerts = activeResponse.alerts
            historyAlerts = historyResponse.alerts
            disclaimer = activeResponse.disclaimer
            lastUpdated = Date()
            if statusResponse.flags.paperAnalyticsEnabled {
                await loadPaperPerformance(accessToken: token)
            }
            await loadScanSummary(accessToken: token)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadScanSummary(accessToken: String) async {
        scanLoading = true
        scanErrorMessage = nil
        defer { scanLoading = false }
        do {
            scanSummary = try await MomentumBreakoutAlertService.fetchScan(
                accessToken: accessToken,
                tradableOnly: false,
                limit: 30
            )
        } catch {
            scanSummary = nil
            scanErrorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadPaperPerformance(accessToken: String) async {
        guard featureFlags.paperAnalyticsEnabled else {
            paperSummary = nil
            return
        }
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

    func cancelAlert(alertId: String) async {
        guard let token = accessToken else {
            errorMessage = "Sign in to view trade plan alerts."
            return
        }
        cancellingAlertId = alertId
        errorMessage = nil
        defer { cancellingAlertId = nil }
        do {
            _ = try await MomentumBreakoutAlertService.cancelAlert(
                accessToken: token,
                alertId: alertId
            )
            async let active = MomentumBreakoutAlertService.fetchActiveAlerts(accessToken: token)
            async let history = MomentumBreakoutAlertService.fetchAlertHistory(accessToken: token)
            let activeResponse = try await active
            let historyResponse = try await history
            activeAlerts = activeResponse.alerts
            historyAlerts = historyResponse.alerts
            lastUpdated = Date()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
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
            await loadScanSummary(accessToken: token)
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
