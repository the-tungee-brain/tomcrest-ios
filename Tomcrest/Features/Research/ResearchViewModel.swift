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
        query = text
        scheduleSearch()
    }

    func selectSymbol(_ item: TickerSymbolItem) {
        query = item.symbol
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            searchError = nil
            return
        }

        isSearching = true
        searchError = nil

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
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
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private(set) var stockChart: StockChartPayload?
    private(set) var isChartLoading = false
    private(set) var chartError: String?
    var chartPeriod: StockChartPeriod = .threeMonths

    private(set) var isBigPictureLoading = false
    private(set) var bigPictureError: String?

    private(set) var chatSessions: [ChatSessionSummary] = []
    private(set) var chatSessionsLoading = false
    var showChatHistory = false
    private(set) var chatMessages: [ChatMessage] = []
    private(set) var chatInput = ""
    private(set) var chatLoading = false
    private(set) var chatExpanded = false

    private var chatSessionId: String?
    private var chatHistoryHydrated = false

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

        chatLoading = false
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
        guard bundle == nil, !isLoading else { return }
        await reload()
    }

    func reload() async {
        guard let accessToken = auth.accessToken else {
            errorMessage = "Sign in to view research."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            bundle = try await ResearchService.fetchOverviewBundle(
                symbol: symbol,
                accessToken: accessToken,
                api: api
            )
            await hydrateChatHistoryIfNeeded()
        } catch {
            bundle = nil
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
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
            stockChart = try await ResearchService.fetchStockChart(
                symbol: symbol,
                accessToken: accessToken,
                period: chartPeriod.rawValue,
                api: api
            )
        } catch {
            stockChart = nil
            chartError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refreshBigPicture() async {
        guard let accessToken = auth.accessToken else { return }

        isBigPictureLoading = true
        bigPictureError = nil
        defer { isBigPictureLoading = false }

        do {
            bundle = try await ResearchService.fetchOverviewBundle(
                symbol: symbol,
                accessToken: accessToken,
                includeSummary: true,
                api: api
            )
        } catch {
            bigPictureError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func startNewChat() {
        chatSessionId = nil
        chatMessages = []
        chatHistoryHydrated = true
        chatExpanded = true
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
