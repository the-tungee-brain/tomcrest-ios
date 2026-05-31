import Foundation

struct AccountPlanResponse: Decodable {
    let plan: String
    let isPaid: Bool
    let identitySub: String?
    let email: String?
    let features: [String: Bool]?
    let freeModel: String
    let defaultModel: String
    let backgroundModel: String?
    let freeModels: [String]?
    let proOnlyModels: [String]?
    let paidModels: [String]?
    let allowedModels: [String]?
    let chatModels: [ChatModelDefinition]?

    var planLabel: String {
        isPaid ? "Pro" : "Free"
    }
}

struct ChatModelDefinition: Decodable, Identifiable {
    let id: String
    let label: String
    let description: String
    let tier: String
}

struct DeleteAccountResponse: Decodable {
    let deleted: Bool
}
