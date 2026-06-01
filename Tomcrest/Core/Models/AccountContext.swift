import Foundation

enum ProFeature: String {
    case earningsAi = "earnings_ai"
    case wheelBacktest = "wheel_backtest"
    case dividendSnowball = "dividend_snowball"
    case newsAi = "news_ai"
    case financialStrength = "financial_strength"
    case business = "business"
    case bigPicture = "big_picture"
}

@MainActor
@Observable
final class AccountContext {
    private(set) var plan: AccountPlanResponse?
    private(set) var isLoadingPlan = false

    private static let freeModelStorageKey = "tomcrest.chatModel.free"
    private static let proModelStorageKey = "tomcrest.chatModel.pro"
    private static let legacyModelStorageKey = "tomcrest.chatModel"

    var selectedChatModel: String = ChatConfig.freeDefaultModel {
        didSet {
            persistSelectedChatModel(selectedChatModel)
        }
    }

    init() {
        migrateLegacySelectionIfNeeded()
        if let saved = UserDefaults.standard.string(forKey: Self.freeModelStorageKey) {
            selectedChatModel = saved
        } else if let legacy = UserDefaults.standard.string(forKey: Self.legacyModelStorageKey) {
            selectedChatModel = legacy
        }
    }

    var defaultChatModel: String {
        guard let plan else { return ChatConfig.freeDefaultModel }
        if plan.isPaid {
            let model = plan.defaultModel.trimmingCharacters(in: .whitespacesAndNewlines)
            return model.isEmpty ? ChatConfig.proDefaultModel : model
        }
        let model = plan.freeModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? ChatConfig.freeDefaultModel : model
    }

    var effectiveChatModel: String {
        let options = chatModelOptions()
        if options.contains(where: { $0.id == selectedChatModel }),
           ChatModelSupport.isAllowed(modelId: selectedChatModel, plan: plan) {
            return selectedChatModel
        }
        return defaultChatModel
    }

    var selectedChatModelLabel: String {
        ChatModelSupport.displayLabel(for: effectiveChatModel, plan: plan)
    }

    func loadPlan(accessToken: String) async {
        isLoadingPlan = true
        defer { isLoadingPlan = false }

        do {
            plan = try await SettingsService.fetchAccountPlan(accessToken: accessToken)
            selectedChatModel = loadPersistedChatModel(isPaid: plan?.isPaid == true)
            normalizeSelectedModel()
        } catch {
            plan = nil
        }
    }

    func clearSession() {
        plan = nil
        isLoadingPlan = false
    }

    func hasProFeature(_ feature: ProFeature) -> Bool {
        guard let plan else { return false }
        if let features = plan.features, let value = features[feature.rawValue] {
            return value
        }
        return plan.isPaid
    }

    func chatModelOptions() -> [ChatModelDefinition] {
        if let models = plan?.chatModels, !models.isEmpty {
            return models
        }
        return ChatModelSupport.fallbackOptions
    }

    func chatModelGroups() -> [(label: String, options: [ChatModelDefinition])] {
        ChatModelSupport.groupedOptions(chatModelOptions())
    }

    func selectChatModel(_ modelId: String) {
        guard ChatModelSupport.isAllowed(modelId: modelId, plan: plan) else { return }
        selectedChatModel = modelId
    }

    func requiresProModel(_ modelId: String) -> Bool {
        ChatModelSupport.requiresPro(modelId: modelId, plan: plan)
    }

    func isModelAllowed(_ modelId: String) -> Bool {
        ChatModelSupport.isAllowed(modelId: modelId, plan: plan)
    }

    private func normalizeSelectedModel() {
        if !ChatModelSupport.isAllowed(modelId: selectedChatModel, plan: plan) {
            selectedChatModel = defaultChatModel
        }
    }

    private func storageKey(isPaid: Bool) -> String {
        isPaid ? Self.proModelStorageKey : Self.freeModelStorageKey
    }

    private func persistSelectedChatModel(_ model: String) {
        let isPaid = plan?.isPaid == true
        UserDefaults.standard.set(model, forKey: storageKey(isPaid: isPaid))
    }

    private func loadPersistedChatModel(isPaid: Bool) -> String {
        migrateLegacySelectionIfNeeded()

        if let saved = UserDefaults.standard.string(forKey: storageKey(isPaid: isPaid)) {
            return saved
        }
        return isPaid ? ChatConfig.proDefaultModel : ChatConfig.freeDefaultModel
    }

    private func migrateLegacySelectionIfNeeded() {
        guard let legacy = UserDefaults.standard.string(forKey: Self.legacyModelStorageKey) else { return }

        if UserDefaults.standard.string(forKey: Self.freeModelStorageKey) == nil {
            UserDefaults.standard.set(legacy, forKey: Self.freeModelStorageKey)
        }
        if UserDefaults.standard.string(forKey: Self.proModelStorageKey) == nil {
            UserDefaults.standard.set(ChatConfig.proDefaultModel, forKey: Self.proModelStorageKey)
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyModelStorageKey)
    }
}

enum ChatModelSupport {
    static let fallbackOptions: [ChatModelDefinition] = [
        ChatModelDefinition(id: "gpt-5-nano", label: "Fast", description: "Quick replies for simple questions", tier: "fast"),
        ChatModelDefinition(id: "gpt-4o-mini", label: "Fast", description: "Lightweight and responsive", tier: "fast"),
        ChatModelDefinition(id: ChatConfig.freeDefaultModel, label: "Balanced", description: "Recommended for most portfolio and research questions", tier: "balanced"),
        ChatModelDefinition(id: "gpt-5.1", label: "Advanced", description: "Strong general-purpose analysis", tier: "advanced"),
        ChatModelDefinition(id: "gpt-4o", label: "Advanced", description: "Reliable depth for everyday use", tier: "advanced"),
        ChatModelDefinition(id: "gpt-5.4", label: "Advanced", description: "Deepest analysis — best for complex questions", tier: "advanced"),
        ChatModelDefinition(id: "o3", label: "Advanced", description: "Maximum reasoning depth, slower responses", tier: "advanced"),
        ChatModelDefinition(id: "o4-mini", label: "Advanced", description: "Strong reasoning with moderate speed", tier: "advanced"),
    ]

    static let tierLabels: [(id: String, label: String)] = [
        ("fast", "Simple"),
        ("balanced", "Standard"),
        ("advanced", "Advanced"),
    ]

    static func groupedOptions(_ options: [ChatModelDefinition]) -> [(label: String, options: [ChatModelDefinition])] {
        tierLabels.compactMap { tier in
            let items = options.filter { $0.tier == tier.id }
            guard !items.isEmpty else { return nil }
            return (tier.label, items)
        }
    }

    static func displayLabel(for modelId: String, plan: AccountPlanResponse?) -> String {
        let tier = tierLabel(for: modelId, plan: plan)
        return "\(tier) · \(modelId)"
    }

    static func tierLabel(for modelId: String, plan: AccountPlanResponse?) -> String {
        let options = plan?.chatModels?.isEmpty == false ? plan!.chatModels! : fallbackOptions
        guard let match = options.first(where: { $0.id == modelId }) else {
            return "Standard"
        }
        return tierLabels.first(where: { $0.id == match.tier })?.label ?? "Standard"
    }

    static func requiresPro(modelId: String, plan: AccountPlanResponse?) -> Bool {
        if let proOnly = plan?.proOnlyModels, !proOnly.isEmpty {
            return proOnly.contains(modelId)
        }
        return matchTier(modelId, plan: plan) == "advanced"
    }

    static func isAllowed(modelId: String, plan: AccountPlanResponse?) -> Bool {
        if plan?.isPaid == true {
            if let allowed = plan?.allowedModels, !allowed.isEmpty {
                return allowed.contains(modelId)
            }
            if let paid = plan?.paidModels, !paid.isEmpty {
                return paid.contains(modelId)
            }
            return matchTier(modelId, plan: plan) != nil
        }
        if let freeModels = plan?.freeModels, !freeModels.isEmpty {
            return freeModels.contains(modelId)
        }
        return !requiresPro(modelId: modelId, plan: plan)
    }

    private static func matchTier(_ modelId: String, plan: AccountPlanResponse?) -> String? {
        let options = plan?.chatModels?.isEmpty == false ? plan!.chatModels! : fallbackOptions
        return options.first(where: { $0.id == modelId })?.tier
    }
}
