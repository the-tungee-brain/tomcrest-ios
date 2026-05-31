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
    private(set) var isRefreshing = false
    private(set) var syncedAtLabel: String?
    private(set) var chatMessages: [ChatMessage] = []
    private(set) var chatInput = ""
    private(set) var chatLoading = false
    private(set) var chatExpanded = false

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

    var canSendChat: Bool {
        chatAccountPayload != nil &&
            chatPositionsPayload != nil &&
            !positions.isEmpty &&
            !chatLoading &&
            !chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateChatInput(_ text: String) {
        chatInput = text
    }

    func toggleChatExpanded() {
        chatExpanded.toggle()
    }

    func sendChatMessage(model: String = ChatConfig.defaultModel) async {
        let prompt = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty,
              !chatLoading,
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
        isRefreshing = true
        defer { isRefreshing = false }

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
            await hydrateChatHistoryIfNeeded()
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
            syncedAtLabel = RelativeDateTimeFormatter().localizedString(
                for: ISO8601DateFormatter().date(from: syncedAt) ?? Date(),
                relativeTo: Date()
            )
        } else {
            syncedAtLabel = nil
        }
    }
}
