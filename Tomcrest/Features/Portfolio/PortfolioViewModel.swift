import Foundation

enum PortfolioScreenState: Equatable {
    case loading
    case schwabNotConnected
    case reauthRequired(String)
    case empty
    case content
    case error(String)
}

@MainActor
@Observable
final class PortfolioViewModel {
    private(set) var screenState: PortfolioScreenState = .loading
    private(set) var snapshot: AccountSnapshot?
    private(set) var positions: [Position] = []
    private(set) var morningBrief: MorningBrief?
    private(set) var displayBrief: PortfolioIntelligence?
    private(set) var alerts: [ProactiveAlert] = []
    private(set) var attentionQueue: [AttentionItem] = []
    private(set) var suggestedActions: [SuggestedAnalysisAction] = []
    private(set) var syncedAtLabel: String?
    private(set) var investmentProfile: UserInvestmentProfile?
    private(set) var strategyCatalog: [StrategyCatalogItem] = []
    private(set) var strategyRecommendations: StrategyRecommendations?
    private(set) var strategyPlaybookLoading = false
    private(set) var isConnectingSchwab = false
    private(set) var showOnboardingWizard = false
    private(set) var portfolioAnalysisExpandedFromBrief = false
    private(set) var cashSecuredPutSummary: CashSecuredPutSummary?
    private(set) var assignmentRiskSummary: AssignmentRiskSummary?
    private(set) var portfolioAnalysisLoading = false
    private(set) var portfolioAnalysisStatus: String?
    private(set) var portfolioAnalysisError: String?
    private(set) var structuredAnalysis: StructuredAnalysis?
    private(set) var portfolioPrecomputed: PortfolioAnalysisPrecomputed?
    private(set) var chatMessages: [ChatMessage] = []
    private(set) var chatInput = ""
    private(set) var chatLoading = false
    private(set) var chatExpanded = false
    var showChatHistory = false
    private(set) var chatSessions: [ChatSessionSummary] = []
    private(set) var chatSessionsLoading = false

    var activeSection: PortfolioSection = .today
    private(set) var portfolioNews: [PortfolioHoldingsNewsItem] = []
    private(set) var portfolioNewsLoading = false
    private var portfolioNewsLoaded = false

    private(set) var recentOrders: [RecentOrderEntry] = []
    private(set) var recentOrdersLoading = false
    private(set) var recentOrdersError: String?
    private(set) var recentOrderCount = 0
    private(set) var totalActivityOrders = 0
    private(set) var activityBySymbol: [String: Int] = [:]
    var activityDaysBack = 30
    var activitySymbolFilter: String?
    private var recentOrdersLoaded = false

    private var chatSessionId: String?
    private var chatHistoryHydrated = false
    private var chatAccountPayload: JSONPassThrough?
    private var chatPositionsPayload: JSONPassThrough?

    private let auth: AuthSession
    private let api: APIClient

    init(auth: AuthSession, api: APIClient = .shared) {
        self.auth = auth
        self.api = api
    }

    var briefLead: String? {
        PortfolioBriefText.lead(from: displayBrief, changes: morningBrief?.changes)
    }

    var briefIsUrgent: Bool {
        (displayBrief?.signals ?? []).contains { $0.severity == .critical || $0.severity == .warning }
    }

    var topBriefSignals: [IntelligenceSignal] {
        Array(IntelligenceHelpers.sortSignalsBySeverity(displayBrief?.signals ?? []).prefix(3))
    }

    var briefDigest: PortfolioDigest? {
        morningBrief?.digest ?? displayBrief?.digest
    }

    func runDiversificationAnalysis() {
        portfolioAnalysisExpandedFromBrief = true
        Task { await runPortfolioAnalysis() }
    }

    func runPortfolioAnalysis() async {
        guard !portfolioAnalysisLoading,
              let accessToken = auth.accessToken,
              let accountPayload = chatAccountPayload,
              let positionsPayload = chatPositionsPayload,
              !positions.isEmpty else { return }

        portfolioAnalysisLoading = true
        portfolioAnalysisError = nil
        portfolioAnalysisStatus = "Reviewing your portfolio…"
        defer { portfolioAnalysisLoading = false }

        do {
            let response = try await PortfolioService.fetchStructuredPortfolioAnalysis(
                account: accountPayload,
                positions: positionsPayload,
                accessToken: accessToken
            ) { [weak self] chunk in
                Task { @MainActor in
                    if chunk.localizedCaseInsensitiveContains("reviewing") {
                        self?.portfolioAnalysisStatus = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            structuredAnalysis = response.analysis
            portfolioPrecomputed = response.portfolioPrecomputed
            portfolioAnalysisStatus = nil
            if response.analysis == nil {
                portfolioAnalysisError = "Could not read the analysis response. Try again."
            }
            auth.clearError()
        } catch {
            portfolioAnalysisError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    var holdingSummaries: [SymbolHoldingSummary] {
        PortfolioHoldingsSupport.buildSummaries(positions: positions, alerts: alerts)
    }

    var totalDayProfitLoss: Double {
        positions.reduce(0) { $0 + $1.currentDayProfitLoss }
    }

    func topHoldings(limit: Int = 6) -> [SymbolHoldingSummary] {
        Array(holdingSummaries.prefix(limit))
    }

    var taxAlertItems: [TaxAlertItem] {
        IntelligenceHelpers.collectTaxAlertItems(
            alerts: alerts,
            suggestedActions: suggestedActions
        )
    }

    var portfolioTradeSuggestions: [SuggestedAnalysisAction] {
        IntelligenceHelpers.portfolioTradeSuggestions(
            alerts: alerts,
            attentionQueue: attentionQueue,
            taxItems: taxAlertItems,
            suggestedActions: suggestedActions
        )
    }

    var attentionItemCount: Int {
        IntelligenceHelpers.countPortfolioAttentionItems(
            taxItems: taxAlertItems,
            alerts: alerts,
            attentionQueue: attentionQueue,
            suggestedActions: suggestedActions
        )
    }

    var canSendChat: Bool {
        chatAccountPayload != nil &&
            chatPositionsPayload != nil &&
            !positions.isEmpty &&
            !chatLoading &&
            !chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var todayBadgeCount: Int {
        attentionItemCount
    }

    var primaryStrategyId: String? {
        investmentProfile?.primaryStrategy
    }

    var strategyCatalogItem: StrategyCatalogItem? {
        guard let primaryStrategyId else { return nil }
        return strategyCatalog.first { $0.id == primaryStrategyId }
    }

    var showStrategyPlaybook: Bool {
        primaryStrategyId != nil
    }

    var needsStrategyOnboarding: Bool {
        investmentProfile?.onboardingCompletedAt == nil
    }

    var showStrategyNudge: Bool {
        needsStrategyOnboarding &&
            OnboardingStorage.isStrategyOnboardingDismissed() &&
            !showOnboardingWizard
    }

    var showPortfolioOnboarding: Bool {
        !OnboardingStorage.isPortfolioOnboardingDismissed() &&
            (screenState == .content || screenState == .empty)
    }

    func presentOnboardingWizard() {
        showOnboardingWizard = true
    }

    func dismissOnboardingWizard() {
        showOnboardingWizard = false
    }

    func dismissStrategyNudge() {
        OnboardingStorage.dismissStrategyOnboarding()
    }

    func dismissPortfolioOnboarding() {
        OnboardingStorage.dismissPortfolioOnboarding()
    }

    func completeStrategyOnboarding(_ update: UserInvestmentProfileUpdate) async {
        guard let accessToken = auth.accessToken else { return }
        do {
            _ = try await StrategyService.updateProfile(update, accessToken: accessToken, api: api)
            if let strategyId = update.primaryStrategy {
                _ = try await StrategyService.selectStrategy(strategyId, accessToken: accessToken, api: api)
            }
            investmentProfile = try await StrategyService.fetchProfile(accessToken: accessToken, api: api)
            await loadStrategyPlaybook(accessToken: accessToken)
            showOnboardingWizard = false
            auth.clearError()
        } catch {
            auth.setError((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func saveStrategyOnboardingDraft(_ update: UserInvestmentProfileUpdate) async {
        guard let accessToken = auth.accessToken else { return }
        _ = try? await StrategyService.updateProfile(update, accessToken: accessToken, api: api)
    }

    func runPlaybookAction(_ action: StrategyNextAction) {
        if action.type == "connect" {
            Task { await connectSchwabFromPlaybook() }
            return
        }
        guard StrategyPlaybookHelpers.playbookActionAskable(action),
              let strategyId = primaryStrategyId else { return }
        Task { await sendPlaybookAsk(action: action, strategyId: strategyId) }
    }

    private func sendPlaybookAsk(action: StrategyNextAction, strategyId: String) async {
        guard let accessToken = auth.accessToken else { return }

        let userMessage = ChatMessage(
            id: "user-\(Date().timeIntervalSince1970)",
            role: .user,
            content: action.title
        )
        chatMessages.append(userMessage)
        chatLoading = true
        chatExpanded = true

        let assistantId = "assistant-\(Date().timeIntervalSince1970)"
        chatMessages.append(ChatMessage(id: assistantId, role: .assistant, content: ""))

        do {
            let completion = try await StrategyService.streamPlaybookAsk(
                action: action,
                strategyId: strategyId,
                accessToken: accessToken,
                chatSessionId: chatSessionId,
                newChatSession: chatSessionId == nil
            ) { [weak self] chunk in
                Task { @MainActor in
                    self?.appendAssistantChunk(chunk, assistantId: assistantId)
                }
            }

            if let sessionId = completion.chatSessionId {
                chatSessionId = sessionId
            }
            auth.clearError()
        } catch {
            appendAssistantChunk(
                "Sorry, something went wrong while answering your playbook question.",
                assistantId: assistantId
            )
            auth.setError((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }

        chatLoading = false
    }

    func connectSchwabFromPlaybook() async {
        guard !isConnectingSchwab else { return }
        isConnectingSchwab = true
        defer { isConnectingSchwab = false }
        _ = await reconnectSchwab()
    }

    var activityBadgeCount: Int {
        recentOrderCount
    }

    func setActiveSection(_ section: PortfolioSection) {
        activeSection = section
        if section == .news {
            Task { await loadPortfolioNewsIfNeeded() }
        } else if section == .activity {
            Task { await loadRecentOrdersIfNeeded() }
        }
    }

    func setActivityDaysBack(_ days: Int) {
        guard activityDaysBack != days else { return }
        activityDaysBack = days
        Task { await loadRecentOrdersIfNeeded(force: true) }
    }

    func setActivitySymbolFilter(_ symbol: String?) {
        let normalized = symbol?.uppercased()
        guard activitySymbolFilter != normalized else { return }
        activitySymbolFilter = normalized
        Task { await loadRecentOrdersIfNeeded(force: true) }
    }

    func loadPortfolioNewsIfNeeded(force: Bool = false) async {
        guard let accessToken = auth.accessToken else { return }
        if portfolioNewsLoading { return }
        if portfolioNewsLoaded, !force { return }

        portfolioNewsLoading = true
        defer { portfolioNewsLoading = false }

        do {
            let response = try await PortfolioService.fetchPortfolioNews(
                accessToken: accessToken,
                api: api
            )
            portfolioNews = response.items
            portfolioNewsLoaded = true
        } catch let error as APIError {
            auth.setError(error.errorDescription ?? "Could not load portfolio news.")
        } catch {
            auth.setError(error.localizedDescription)
        }
    }

    func loadRecentOrdersIfNeeded(force: Bool = false) async {
        guard let accessToken = auth.accessToken else { return }
        if recentOrdersLoading { return }
        if recentOrdersLoaded, !force { return }

        recentOrdersLoading = true
        recentOrdersError = nil
        defer { recentOrdersLoading = false }

        do {
            let response = try await PortfolioService.fetchRecentOrders(
                accessToken: accessToken,
                symbol: activitySymbolFilter,
                daysBack: activityDaysBack,
                refresh: force,
                api: api
            )
            recentOrders = response.orders
            totalActivityOrders = response.totalOrders
            recentOrderCount = response.recentOrderCount
            if activitySymbolFilter == nil {
                activityBySymbol = response.activityBySymbol ?? [:]
            }
            recentOrdersLoaded = true
            auth.clearError()
        } catch let error as APIError {
            recentOrdersError = error.errorDescription ?? "Could not load recent trade activity."
        } catch {
            recentOrdersError = error.localizedDescription
        }
    }

    func updateChatInput(_ text: String) {
        chatInput = text
    }

    func toggleChatExpanded() {
        chatExpanded.toggle()
    }

    func openChatWithPrompt(_ prompt: String) {
        chatInput = prompt
        chatExpanded = true
    }

    func runQuickAction(_ actionId: String) -> String {
        IntelligenceHelpers.quickActionMessage(actionId: actionId, symbol: "my portfolio")
    }

    func sendChatMessage(model: String = ChatConfig.defaultModel) async {
        let prompt = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        await sendChatPrompt(prompt, model: model)
    }

    func sendFollowUpPrompt(_ prompt: String, model: String = ChatConfig.defaultModel) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await sendChatPrompt(trimmed, model: model)
    }

    private func sendChatPrompt(_ prompt: String, model: String) async {
        guard !chatLoading,
              chatAccountPayload != nil,
              chatPositionsPayload != nil,
              !positions.isEmpty,
              let accessToken = auth.accessToken,
              let accountPayload = chatAccountPayload,
              let positionsPayload = chatPositionsPayload else { return }

        let userMessage = ChatMessage(
            id: "user-\(Date().timeIntervalSince1970)",
            role: .user,
            content: prompt
        )
        chatMessages.append(userMessage)
        chatInput = ""
        chatLoading = true
        chatExpanded = true

        let assistantId = "assistant-\(Date().timeIntervalSince1970)"
        chatMessages.append(ChatMessage(id: assistantId, role: .assistant, content: ""))

        do {
            let completion = try await PortfolioService.streamPortfolioChat(
                account: accountPayload,
                positions: positionsPayload,
                prompt: prompt,
                accessToken: accessToken,
                model: model,
                chatSessionId: chatSessionId,
                newChatSession: chatSessionId == nil
            ) { [weak self] chunk in
                Task { @MainActor in
                    self?.appendAssistantChunk(chunk, assistantId: assistantId)
                }
            }

            if let sessionId = completion.chatSessionId {
                chatSessionId = sessionId
            }

            if chatMessages.first(where: { $0.id == assistantId })?
                .content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == true {
                appendAssistantChunk(
                    "Sorry, I didn't get a response back. Please try again or rephrase your question.",
                    assistantId: assistantId
                )
            }
            await hydrateChatHistoryIfNeeded(force: true)
            auth.clearError()
        } catch {
            appendAssistantChunk(
                "Sorry, something went wrong while analyzing your portfolio.",
                assistantId: assistantId
            )
            auth.setError((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }

        chatLoading = false
    }

    private func appendAssistantChunk(_ chunk: String, assistantId: String) {
        guard !chunk.isEmpty,
              let index = chatMessages.firstIndex(where: { $0.id == assistantId }) else { return }
        chatMessages[index].content += chunk
    }

    func hydrateChatHistoryIfNeeded(force: Bool = false) async {
        guard let accessToken = auth.accessToken else { return }
        if chatHistoryHydrated, !force, !chatMessages.isEmpty { return }

        guard let loaded = await ChatHistoryLoader.hydrate(
            scope: .portfolio,
            sessionId: chatSessionId,
            localMessages: chatMessages,
            accessToken: accessToken
        ) else {
            chatHistoryHydrated = true
            return
        }

        if ChatHistoryLoader.shouldApplyServerHistory(
            localMessages: chatMessages,
            serverMessages: loaded.messages
        ) {
            chatMessages = loaded.messages
        }
        chatSessionId = loaded.sessionId
        chatHistoryHydrated = true
    }

    func startNewChat() {
        chatSessionId = nil
        chatMessages = []
        chatHistoryHydrated = true
        chatExpanded = true
    }

    func clearChat() {
        guard !chatMessages.isEmpty, !chatLoading else { return }
        startNewChat()
    }

    func loadChatSessions() async {
        guard let accessToken = auth.accessToken else { return }
        chatSessionsLoading = true
        defer { chatSessionsLoading = false }

        do {
            chatSessions = try await ChatService.listSessions(
                accessToken: accessToken,
                kind: ChatHistoryScope.portfolio.sessionKind
            )
        } catch {
            chatSessions = []
        }
    }

    func openChatSession(_ session: ChatSessionSummary) async {
        guard let accessToken = auth.accessToken else { return }
        showChatHistory = false
        chatLoading = true
        defer { chatLoading = false }

        do {
            if let loaded = try await ChatHistoryLoader.loadSession(
                sessionId: session.id,
                accessToken: accessToken
            ) {
                chatSessionId = loaded.sessionId
                chatMessages = loaded.messages
                chatHistoryHydrated = true
                chatExpanded = true
            }
        } catch {
            auth.setError((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func deleteChatSession(_ session: ChatSessionSummary) async {
        guard let accessToken = auth.accessToken else { return }

        do {
            try await ChatService.deleteSession(sessionId: session.id, accessToken: accessToken)
            chatSessions.removeAll { $0.id == session.id }
            if chatSessionId == session.id {
                startNewChat()
            }
            auth.clearError()
        } catch {
            auth.setError((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func loadIfNeeded() async {
        guard screenState == .loading else { return }
        await refresh()
    }

    func refresh(fromPull: Bool = false) async {
        guard let accessToken = auth.accessToken else { return }

        let preserveContent = screenState == .content || screenState == .empty
        if !preserveContent {
            screenState = .loading
        }
        let schwabConnected = await auth.fetchSchwabStatus()
        if schwabConnected == false {
            screenState = .schwabNotConnected
            return
        }

        do {
            async let positionsTask = PortfolioService.fetchPositions(
                accessToken: accessToken,
                refresh: fromPull,
                api: api
            )
            async let briefTask = fetchMorningBriefOptional(
                accessToken: accessToken,
                refresh: fromPull
            )

            let fetchResult = try await positionsTask
            let brief = await briefTask

            apply(fetchResult: fetchResult, morningBrief: brief)
            screenState = positions.isEmpty ? .empty : .content
            await loadStrategyPlaybook(accessToken: accessToken)
            await hydrateChatHistoryIfNeeded()
            if portfolioNewsLoaded || activeSection == .news {
                await loadPortfolioNewsIfNeeded(force: fromPull)
            }
            if recentOrdersLoaded || activeSection == .activity {
                await loadRecentOrdersIfNeeded(force: fromPull)
            }
            auth.clearError()
        } catch let error as APIError {
            if case let .schwabReauth(detail) = error {
                let message = detail.message ?? "Schwab re-authorization required."
                screenState = .reauthRequired(message)
                auth.setError(message)
                return
            }
            if preserveContent {
                auth.setError(error.errorDescription ?? "Could not refresh portfolio.")
            } else {
                screenState = .error(error.errorDescription ?? "Could not load portfolio.")
                auth.setError(error.errorDescription ?? "Could not load portfolio.")
            }
        } catch {
            if preserveContent {
                auth.setError(error.localizedDescription)
            } else {
                screenState = .error(error.localizedDescription)
                auth.setError(error.localizedDescription)
            }
        }
    }

    func dismissAttentionItem(_ item: AttentionItem) async {
        guard let alertId = item.alertId, let accessToken = auth.accessToken else { return }

        do {
            try await PortfolioService.dismissAlert(alertId: alertId, accessToken: accessToken, api: api)
            attentionQueue.removeAll { $0.alertId == alertId }
        } catch {
            auth.setError((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func reconnectSchwab() async -> Bool {
        let result = await auth.connectSchwab()
        switch result {
        case .success:
            await refresh(fromPull: true)
            return true
        case .cancelled:
            return false
        case let .failed(message):
            screenState = .reauthRequired(message)
            return false
        }
    }

    private func fetchMorningBriefOptional(accessToken: String, refresh: Bool) async -> MorningBrief? {
        do {
            return try await PortfolioService.fetchMorningBrief(
                accessToken: accessToken,
                refresh: refresh,
                api: api
            )
        } catch let error as APIError {
            if case .httpStatus(404, _) = error {
                return nil
            }
            return nil
        } catch {
            return nil
        }
    }

    private func apply(fetchResult: PortfolioFetchResult, morningBrief: MorningBrief?) {
        let positionsResponse = fetchResult.response
        chatAccountPayload = fetchResult.accountPayload
        chatPositionsPayload = fetchResult.positionsPayload

        positions = positionsResponse.flattenedPositions.sorted {
            ($0.portfolioWeightPct ?? 0) > ($1.portfolioWeightPct ?? 0)
        }
        snapshot = AccountSnapshot(
            account: positionsResponse.account,
            metrics: positionsResponse.portfolioMetrics,
            positions: positions
        )
        cashSecuredPutSummary = positionsResponse.cashSecuredPutSummary
        assignmentRiskSummary = positionsResponse.assignmentRiskSummary
        self.morningBrief = morningBrief

        let seedBrief = positionsResponse.portfolioBrief
            ?? PortfolioIntelligence(signals: [], alerts: positionsResponse.proactiveAlerts ?? [])

        if let morningBrief {
            displayBrief = morningBrief.portfolioIntelligence
            attentionQueue = morningBrief.attentionQueue
        } else {
            displayBrief = seedBrief
            attentionQueue = []
        }

        alerts = PortfolioAlerts.merged(
            proactive: positionsResponse.proactiveAlerts ?? [],
            brief: displayBrief
        )

        if let syncedAt = positionsResponse.dataFreshness?.positionsSyncedAt {
            syncedAtLabel = DateFormatters.display(from: syncedAt)
        } else {
            syncedAtLabel = nil
        }

        if let summary = positionsResponse.recentActivity {
            recentOrderCount = summary.recentOrderCount
            totalActivityOrders = summary.totalOrders
            activityDaysBack = summary.daysBack
            suggestedActions = summary.suggestedActions ?? []
        }
    }

    private func loadStrategyPlaybook(accessToken: String) async {
        strategyPlaybookLoading = true
        defer { strategyPlaybookLoading = false }

        do {
            async let profileTask = StrategyService.fetchProfile(accessToken: accessToken, api: api)
            async let catalogTask = StrategyService.fetchCatalog(accessToken: accessToken, api: api)

            let profile = try await profileTask
            let catalog = try await catalogTask
            investmentProfile = profile
            strategyCatalog = catalog

            guard let strategyId = profile?.primaryStrategy else {
                strategyRecommendations = nil
                return
            }

            strategyRecommendations = try await StrategyService.fetchRecommendations(
                strategyId: strategyId,
                accessToken: accessToken,
                api: api
            )
        } catch let error as APIError {
            if case .httpStatus(404, _) = error {
                strategyRecommendations = nil
                return
            }
            auth.setError(error.errorDescription ?? "Could not load strategy playbook.")
        } catch {
            auth.setError(error.localizedDescription)
        }
    }
}
