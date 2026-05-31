import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    var schwabConnected: Bool?
    var isLoadingSchwab = false

    var accountPlan: AccountPlanResponse?
    var isLoadingPlan = false
    var planError: String?

    var bannerMessage: String?
    var bannerIsSuccess = false

    var confirmDelete = false
    var isDeletingAccount = false
    var deleteError: String?

    var strategyCatalog: [StrategyCatalogItem] = []
    var investmentProfile: UserInvestmentProfile?
    var strategyJourney: UserStrategyJourney?
    var isLoadingStrategy = false
    var strategyError: String?
    var isSavingStrategy = false
    var strategySavedMessage: String?
    var updatingJourneyStepId: String?

    private(set) var isRefreshing = false
    private(set) var hasLoadedOnce = false

    private var bannerDismissTask: Task<Void, Never>?

    var selectedStrategyId: String?
    var selectedRiskTolerance = "moderate"
    var watchlistSymbolsText = ""

    private let auth: AuthSession

    init(auth: AuthSession) {
        self.auth = auth
    }

    func load() async {
        let backgroundRefresh = hasLoadedOnce
        if backgroundRefresh {
            isRefreshing = true
        }
        defer {
            isRefreshing = false
            hasLoadedOnce = true
        }

        await refreshSchwabStatus()
        await refreshAccountPlan()
        await refreshStrategy()
    }

    func refreshSchwabStatus() async {
        isLoadingSchwab = true
        schwabConnected = await auth.fetchSchwabStatus()
        isLoadingSchwab = false
    }

    func refreshAccountPlan() async {
        guard let accessToken = auth.accessToken else {
            accountPlan = nil
            planError = nil
            return
        }

        isLoadingPlan = true
        planError = nil
        defer { isLoadingPlan = false }

        do {
            accountPlan = try await SettingsService.fetchAccountPlan(accessToken: accessToken)
        } catch {
            planError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func connectSchwab() async {
        isLoadingSchwab = true
        bannerMessage = nil
        let result = await auth.connectSchwab()
        switch result {
        case .success:
            schwabConnected = true
            showBanner("Schwab connected.", success: true)
        case .cancelled:
            break
        case let .failed(message):
            showBanner(message, success: false)
        }
        isLoadingSchwab = false
    }

    func disconnectSchwab() async {
        isLoadingSchwab = true
        bannerMessage = nil
        if await auth.disconnectSchwab() {
            schwabConnected = false
            showBanner("Schwab disconnected.", success: true)
        } else if let error = auth.lastError {
            showBanner(error, success: false)
        }
        isLoadingSchwab = false
    }

    func beginDeleteAccount() {
        deleteError = nil
        confirmDelete = true
    }

    func cancelDeleteAccount() {
        deleteError = nil
        confirmDelete = false
    }

    func deleteAccount() async {
        guard let accessToken = auth.accessToken else {
            deleteError = "Sign in to delete your account."
            return
        }

        isDeletingAccount = true
        deleteError = nil
        defer { isDeletingAccount = false }

        do {
            _ = try await SettingsService.deleteAccount(accessToken: accessToken)
            confirmDelete = false
            auth.signOut()
        } catch {
            deleteError = (error as? APIError)?.errorDescription
                ?? "Could not delete your account. Please try again."
        }
    }

    func signOut() {
        auth.signOut()
    }

    func refreshStrategy() async {
        guard let accessToken = auth.accessToken else {
            strategyCatalog = []
            investmentProfile = nil
            strategyError = nil
            return
        }

        isLoadingStrategy = true
        strategyError = nil
        defer { isLoadingStrategy = false }

        do {
            async let catalogTask = StrategyService.fetchCatalog(accessToken: accessToken)
            async let profileTask = StrategyService.fetchProfile(accessToken: accessToken)
            strategyCatalog = try await catalogTask
            investmentProfile = try await profileTask
            applyStrategyForm(from: investmentProfile)
            await refreshJourney(accessToken: accessToken)
        } catch {
            strategyError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func selectStrategy(_ strategyId: String) {
        selectedStrategyId = strategyId
        strategySavedMessage = nil
    }

    func updateRiskTolerance(_ value: String) {
        selectedRiskTolerance = value
        strategySavedMessage = nil
    }

    func updateWatchlistSymbols(_ text: String) {
        watchlistSymbolsText = text
        strategySavedMessage = nil
    }

    var selectedStrategyTitle: String? {
        guard let selectedStrategyId else { return nil }
        return strategyCatalog.first(where: { $0.id == selectedStrategyId })?.title
    }

    var canSaveStrategy: Bool {
        guard selectedStrategyId != nil else { return false }
        if selectedStrategyId == "etf-core" { return true }
        return !StrategyFormSupport.parseSymbols(watchlistSymbolsText).isEmpty
    }

    func addSymbolToWatchlist(_ symbol: String) async {
        var symbols = StrategyFormSupport.parseSymbols(watchlistSymbolsText)
        let upper = symbol.uppercased()
        guard !symbols.contains(upper) else { return }
        symbols.append(upper)
        watchlistSymbolsText = symbols.joined(separator: ", ")
        await saveStrategy()
    }

    func saveStrategy() async {
        guard let accessToken = auth.accessToken,
              let strategyId = selectedStrategyId,
              canSaveStrategy else { return }

        isSavingStrategy = true
        strategyError = nil
        strategySavedMessage = nil
        defer { isSavingStrategy = false }

        let symbols = StrategyFormSupport.parseSymbols(watchlistSymbolsText)
        let update = StrategyFormSupport.buildUpdate(
            strategyId: strategyId,
            riskTolerance: selectedRiskTolerance,
            symbols: symbols,
            profile: investmentProfile
        )

        do {
            if investmentProfile?.primaryStrategy != strategyId {
                strategyJourney = try await StrategyService.selectStrategy(strategyId, accessToken: accessToken)
            }
            investmentProfile = try await StrategyService.updateProfile(update, accessToken: accessToken)
            applyStrategyForm(from: investmentProfile)
            await refreshJourney(accessToken: accessToken)
            strategySavedMessage = "Strategy saved."
        } catch {
            strategyError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func completeJourneyStep(_ stepId: String) async {
        guard let accessToken = auth.accessToken,
              let strategyId = investmentProfile?.primaryStrategy else { return }

        updatingJourneyStepId = stepId
        defer { updatingJourneyStepId = nil }

        do {
            strategyJourney = try await StrategyService.updateJourneyStep(
                strategyId: strategyId,
                stepId: stepId,
                status: "completed",
                accessToken: accessToken
            )
        } catch {
            strategyError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func refreshJourney(accessToken: String) async {
        guard let strategyId = investmentProfile?.primaryStrategy else {
            strategyJourney = nil
            return
        }

        do {
            strategyJourney = try await StrategyService.fetchJourney(
                strategyId: strategyId,
                accessToken: accessToken
            )
        } catch {
            strategyJourney = nil
        }
    }

    private func applyStrategyForm(from profile: UserInvestmentProfile?) {
        selectedStrategyId = profile?.primaryStrategy ?? strategyCatalog.first?.id
        selectedRiskTolerance = profile?.riskTolerance ?? "moderate"
        let symbols = StrategyFormSupport.symbols(from: profile)
        watchlistSymbolsText = symbols.joined(separator: ", ")
    }

    private func showBanner(_ message: String, success: Bool) {
        bannerDismissTask?.cancel()
        bannerMessage = message
        bannerIsSuccess = success
        bannerDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            bannerMessage = nil
        }
    }
}
