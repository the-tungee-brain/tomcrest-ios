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

    private let selectedModelKey = "tomcrest.chatModel"

    var selectedChatModel: String {
        get {
            UserDefaults.standard.string(forKey: selectedModelKey) ?? defaultChatModel
        }
        set {
            UserDefaults.standard.set(newValue, forKey: selectedModelKey)
        }
    }

    var defaultChatModel: String {
        guard let plan else { return ChatConfig.defaultModel }
        return plan.isPaid ? plan.defaultModel : plan.freeModel
    }

    var effectiveChatModel: String {
        let options = chatModelOptions()
        if options.contains(where: { $0.id == selectedChatModel }) {
            if requiresProModel(selectedChatModel), plan?.isPaid != true {
                return defaultChatModel
            }
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
            normalizeSelectedModel()
        } catch {
            plan = nil
        }
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
        if requiresProModel(modelId), plan?.isPaid != true { return }
        selectedChatModel = modelId
    }

    func requiresProModel(_ modelId: String) -> Bool {
        ChatModelSupport.requiresPro(modelId: modelId, plan: plan)
    }

    private func normalizeSelectedModel() {
        let allowed = effectiveChatModel
        if selectedChatModel != allowed {
            selectedChatModel = allowed
        }
    }
}

enum ChatModelSupport {
    static let fallbackOptions: [ChatModelDefinition] = [
        ChatModelDefinition(id: "gpt-5-nano", label: "Fast", description: "Quick replies", tier: "fast"),
        ChatModelDefinition(id: "gpt-4o-mini", label: "Fast", description: "Lightweight", tier: "fast"),
        ChatModelDefinition(id: ChatConfig.defaultModel, label: "Balanced", description: "Recommended default", tier: "balanced"),
        ChatModelDefinition(id: "gpt-5.1", label: "Advanced", description: "Strong analysis", tier: "advanced"),
        ChatModelDefinition(id: "gpt-4o", label: "Advanced", description: "Reliable depth", tier: "advanced"),
        ChatModelDefinition(id: "gpt-5.4", label: "Advanced", description: "Deepest analysis", tier: "advanced"),
        ChatModelDefinition(id: "o3", label: "Advanced", description: "Maximum reasoning", tier: "advanced"),
        ChatModelDefinition(id: "o4-mini", label: "Advanced", description: "Strong reasoning", tier: "advanced"),
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
        let options = plan?.chatModels?.isEmpty == false ? plan!.chatModels! : fallbackOptions
        guard let match = options.first(where: { $0.id == modelId }) else {
            return "Balanced"
        }
        let tier = tierLabels.first(where: { $0.id == match.tier })?.label ?? "Standard"
        return "\(tier) · \(match.label)"
    }

    static func requiresPro(modelId: String, plan: AccountPlanResponse?) -> Bool {
        if let proOnly = plan?.proOnlyModels, proOnly.contains(modelId) { return true }
        if let paid = plan?.paidModels, paid.contains(modelId) { return plan?.isPaid != true }
        if let allowed = plan?.allowedModels, !allowed.contains(modelId) { return true }
        return matchTier(modelId, plan: plan) == "advanced" && plan?.isPaid != true
    }

    private static func matchTier(_ modelId: String, plan: AccountPlanResponse?) -> String? {
        let options = plan?.chatModels?.isEmpty == false ? plan!.chatModels! : fallbackOptions
        return options.first(where: { $0.id == modelId })?.tier
    }
}
