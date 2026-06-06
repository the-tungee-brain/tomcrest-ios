import CoreGraphics
import Foundation

@MainActor
@Observable
final class ResearchViewModel {
    var query = ""
    private(set) var results: [TickerSymbolItem] = []
    private(set) var isSearching = false
    private(set) var searchError: String?

    private let auth: AuthSession
    private let api: APIClient
    private var searchTask: Task<Void, Never>?

    init(auth: AuthSession, api: APIClient = .shared) {
        self.auth = auth
        self.api = api
    }

    func updateQuery(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            query = ""
            results = []
            isSearching = false
            searchError = nil
            return
        }

        searchError = nil

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            query = trimmed
            isSearching = true
            await performSearch(trimmed)
        }
    }

    func selectSymbol(_ item: TickerSymbolItem) {
        query = item.symbol
    }

    private func performSearch(_ keyword: String) async {
        guard let accessToken = auth.accessToken else {
            results = []
            isSearching = false
            searchError = "Sign in to search symbols."
            return
        }

        do {
            let items = try await ResearchService.searchSymbols(
                query: keyword,
                accessToken: accessToken,
                api: api
            )
            guard !Task.isCancelled else { return }
            results = items
            searchError = nil
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            searchError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }

        isSearching = false
    }
}

@MainActor
@Observable
final class SymbolOverviewViewModel {
    let symbol: String

    private(set) var bundle: ResearchOverviewBundle?
    private(set) var snapshot: ResearchSnapshot?
    private(set) var performance: PerformanceSnapshot?
    private(set) var events: [EventTimelineEntry] = []
    private(set) var tradingBias: TradingBiasResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var snapshotLoading = false
    private(set) var performanceLoading = false
    private(set) var eventsLoading = false
    private(set) var tradingBiasLoading = false
    private(set) var snapshotError: String?
    private(set) var performanceError: String?
    private(set) var eventsError: String?
    private(set) var tradingBiasError: String?

    private(set) var stockChart: StockChartPayload?
    private(set) var preparedStockChart: IntradayChartTimeline.PreparedChart?
    private(set) var isChartLoading = false
    private(set) var chartError: String?
    var chartPeriod: StockChartPeriod = .oneDay

    private(set) var chatSessions: [ChatSessionSummary] = []
    private(set) var chatSessionsLoading = false
    var showChatHistory = false
    private(set) var chatMessages: [ChatMessage] = []
    private(set) var chatInput = ""
    private(set) var chatLoading = false
    private(set) var chatExpanded = false

    private var chatSessionId: String?
    private var chatHistoryHydrated = false
    private var overviewLoaded = false
    @ObservationIgnored private var chatStreamThrottler: ChatStreamThrottler

    private let auth: AuthSession
    private let api: APIClient

    private static let suggestedPromptTemplates: [(label: String, prompt: (String) -> String)] = [
        ("Bull/bear case", { symbol in
            "Summarize the bull case and bear case for \(symbol) in plain English — 3 bullets each, then which side the data favors today."
        }),
        ("Key risks", { symbol in
            "What are the top 3 business and market risks for \(symbol) over the next 6–12 months, and what would show up in the stock first?"
        }),
        ("Competitive moat", { symbol in
            "How durable is \(symbol)'s competitive moat versus its main peers, and where is it most vulnerable?"
        }),
        ("Earnings preview", { symbol in
            "What should I watch in the next earnings report for \(symbol) — key metrics, guidance, and how the stock might react?"
        }),
    ]

    var suggestedPromptLabels: [String] {
        Self.suggestedPromptTemplates.map(\.label)
    }

    var canSendChat: Bool {
        !chatLoading &&
            !chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(symbol: String, auth: AuthSession, api: APIClient = .shared) {
        self.symbol = symbol.uppercased()
        self.auth = auth
        self.api = api
        self.chatStreamThrottler = ChatStreamThrottler()
        self.chatStreamThrottler.apply = { [weak self] assistantId, chunk in
            guard let self,
                  let index = self.chatMessages.firstIndex(where: { $0.id == assistantId }) else { return }
            self.chatMessages[index].content += chunk
        }
    }

    func suggestedPrompt(for label: String) -> String? {
        guard let template = Self.suggestedPromptTemplates.first(where: { $0.label == label }) else {
            return nil
        }
        return template.prompt(symbol)
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
              let accessToken = auth.accessToken else { return }

        let userMessage = ChatMessage(
            id: "user-\(Date().timeIntervalSince1970)",
            role: .user,
            content: prompt
        )
        chatMessages.append(userMessage)
        chatInput = ""
        chatLoading = true
        chatExpanded = true
        defer {
            chatStreamThrottler.flushAll()
            chatLoading = false
        }

        let assistantId = "assistant-\(Date().timeIntervalSince1970)"
        chatMessages.append(ChatMessage(id: assistantId, role: .assistant, content: ""))

        do {
            let completion = try await ResearchService.streamResearchChat(
                symbol: symbol,
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

            ResearchSymbolStorage.markResearchChatUsed()

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
                "Sorry, something went wrong while researching this symbol.",
                assistantId: assistantId
            )
            auth.setError((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func sendPlaybookAsk(action: StrategyNextAction, strategyId: String) async {
        guard let accessToken = auth.accessToken else { return }

        chatMessages.append(ChatMessage(
            id: "user-\(Date().timeIntervalSince1970)",
            role: .user,
            content: action.title
        ))
        chatLoading = true
        chatExpanded = true
        defer {
            chatStreamThrottler.flushAll()
            chatLoading = false
        }

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
            ResearchSymbolStorage.markResearchChatUsed()
            auth.clearError()
        } catch {
            appendAssistantChunk(
                "Sorry, something went wrong while answering your playbook question.",
                assistantId: assistantId
            )
            auth.setError((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func appendAssistantChunk(_ chunk: String, assistantId: String) {
        chatStreamThrottler.append(chunk, assistantId: assistantId)
    }

    func hydrateChatHistoryIfNeeded(force: Bool = false) async {
        guard let accessToken = auth.accessToken else { return }
        if chatHistoryHydrated, !force, !chatMessages.isEmpty { return }

        guard let loaded = await ChatHistoryLoader.hydrate(
            scope: .research(symbol: symbol),
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

    func loadIfNeeded() async {
        guard !overviewLoaded else { return }
        guard !isLoading else { return }
        await reload()
    }

    func reload() async {
        guard let accessToken = auth.accessToken else {
            errorMessage = "Sign in to view research."
            return
        }

        isLoading = true
        errorMessage = nil
        snapshotLoading = true
        performanceLoading = true
        eventsLoading = true
        tradingBiasLoading = true
        snapshotError = nil
        performanceError = nil
        eventsError = nil
        tradingBiasError = nil
        defer { isLoading = false }

        async let snapshotResult = fetchSnapshotResult(accessToken: accessToken)
        async let performanceResult = fetchPerformanceResult(accessToken: accessToken)
        async let eventsResult = fetchEventsResult(accessToken: accessToken)
        async let tradingBiasResult = fetchTradingBiasResult(accessToken: accessToken)

        switch await snapshotResult {
        case let .success(value):
            snapshot = value
            snapshotError = nil
        case let .failure(error):
            snapshot = nil
            snapshotError = displayMessage(for: error)
        }
        snapshotLoading = false

        switch await performanceResult {
        case let .success(value):
            performance = value
            performanceError = nil
        case let .failure(error):
            performance = nil
            performanceError = displayMessage(for: error)
        }
        performanceLoading = false

        switch await eventsResult {
        case let .success(value):
            events = value.events
            eventsError = nil
        case let .failure(error):
            events = []
            eventsError = displayMessage(for: error)
        }
        eventsLoading = false

        switch await tradingBiasResult {
        case let .success(value):
            tradingBias = value
            tradingBiasError = nil
        case let .failure(error):
            tradingBias = nil
            tradingBiasError = displayMessage(for: error)
        }
        tradingBiasLoading = false

        if snapshot == nil, performance == nil, events.isEmpty, tradingBias == nil {
            errorMessage = snapshotError ?? performanceError ?? eventsError ?? tradingBiasError
        }
        overviewLoaded = true

        Task { await hydrateChatHistoryIfNeeded() }
    }

    private func fetchSnapshotResult(accessToken: String) async -> Result<ResearchSnapshot, Error> {
        do {
            let value = try await ResearchService.fetchSnapshot(
                symbol: symbol,
                accessToken: accessToken,
                api: api
            )
            return .success(value)
        } catch {
            return .failure(error)
        }
    }

    private func fetchPerformanceResult(accessToken: String) async -> Result<PerformanceSnapshot, Error> {
        do {
            let value = try await ResearchService.fetchPerformance(
                symbol: symbol,
                accessToken: accessToken,
                api: api
            )
            return .success(value)
        } catch {
            return .failure(error)
        }
    }

    private func fetchEventsResult(accessToken: String) async -> Result<ResearchEventsResponse, Error> {
        do {
            let value = try await ResearchService.fetchResearchEvents(
                symbol: symbol,
                accessToken: accessToken,
                api: api
            )
            return .success(value)
        } catch {
            return .failure(error)
        }
    }

    private func fetchTradingBiasResult(accessToken: String) async -> Result<TradingBiasResponse, Error> {
        do {
            let value = try await ResearchService.fetchTradingBias(
                symbol: symbol,
                accessToken: accessToken,
                api: api
            )
            return .success(value)
        } catch {
            return .failure(error)
        }
    }

    private func displayMessage(for error: Error) -> String {
        (error as? APIError)?.errorDescription ?? error.localizedDescription
    }

    func loadStockChartIfNeeded() async {
        guard stockChart == nil else { return }
        await loadStockChart()
    }

    func loadStockChart() async {
        guard let accessToken = auth.accessToken else { return }

        isChartLoading = true
        chartError = nil
        defer { isChartLoading = false }

        do {
            let chart = try await ResearchService.fetchStockChart(
                symbol: symbol,
                accessToken: accessToken,
                period: chartPeriod.rawValue,
                interval: chartPeriod.interval,
                api: api
            )
            stockChart = chart
            preparedStockChart = Self.buildPreparedChart(from: chart, period: chartPeriod)
            chartError = nil
        } catch {
            stockChart = nil
            preparedStockChart = nil
            chartError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private static func buildPreparedChart(
        from chart: StockChartPayload,
        period: StockChartPeriod
    ) -> IntradayChartTimeline.PreparedChart {
        if period.isRobinhoodIntradaySession {
            return IntradayChartTimeline.prepare(
                rawPoints: chart.data,
                previousClose: chart.previousClose
            )
        }
        return IntradayChartTimeline.PreparedChart(
            points: chart.data,
            values: chart.data.map { CGFloat($0.close) },
            occupyingRelativeWidth: 1
        )
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
                kind: ChatHistoryScope.research(symbol: symbol).sessionKind
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
}
