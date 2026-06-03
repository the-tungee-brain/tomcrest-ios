import Foundation

struct BusinessBlock: Decodable {
    let industry: String
    let primaryProduct: String
    let revenueModel: String
    let primaryCustomers: [String]
    let howTheyMakeMoney: [String]
    let revenueVisibility: [String]
    let advantages: [String]
    let challenges: [String]
    let revenueDrivers: [String]
    let constraints: [String]
    let businessRisks: [String]
    let dependencies: [String]

    enum CodingKeys: String, CodingKey {
        case industry, primaryProduct, revenueModel, primaryCustomers
        case howTheyMakeMoney, revenueVisibility, advantages, challenges
        case revenueDrivers, constraints, businessRisks, dependencies
        case growthDrivers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        industry = try c.decodeIfPresent(String.self, forKey: .industry) ?? ""
        primaryProduct = try c.decodeIfPresent(String.self, forKey: .primaryProduct) ?? ""
        revenueModel = try c.decodeIfPresent(String.self, forKey: .revenueModel) ?? ""
        primaryCustomers = try c.decodeIfPresent([String].self, forKey: .primaryCustomers) ?? []
        howTheyMakeMoney = try c.decodeIfPresent([String].self, forKey: .howTheyMakeMoney) ?? []
        revenueVisibility = try c.decodeIfPresent([String].self, forKey: .revenueVisibility) ?? []
        advantages = try c.decodeIfPresent([String].self, forKey: .advantages) ?? []
        challenges = try c.decodeIfPresent([String].self, forKey: .challenges) ?? []
        revenueDrivers =
            try c.decodeIfPresent([String].self, forKey: .revenueDrivers)
            ?? c.decodeIfPresent([String].self, forKey: .growthDrivers)
            ?? []
        constraints = try c.decodeIfPresent([String].self, forKey: .constraints) ?? []
        businessRisks = try c.decodeIfPresent([String].self, forKey: .businessRisks) ?? []
        dependencies = try c.decodeIfPresent([String].self, forKey: .dependencies) ?? []
    }
}
