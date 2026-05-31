import Foundation

struct BusinessBlock: Decodable {
    let whatTheyDo: String
    let segments: [String]
    let revenueNotes: String
    let customersAndMarkets: String
    let competitiveLandscape: String
    let moatAndDifferentiators: String
    let growthDrivers: [String]
    let keyRisks: [String]
}

enum BusinessArticleSupport {
    static func atAGlance(from business: BusinessBlock) -> [String] {
        var points: [String] = []

        let revenueLead = business.revenueNotes
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ". ")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let revenueLead, !revenueLead.isEmpty {
            points.append(revenueLead.hasSuffix(".") ? revenueLead : "\(revenueLead).")
        }

        if let growth = business.growthDrivers.first?.trimmingCharacters(in: .whitespacesAndNewlines), !growth.isEmpty {
            points.append(growth)
        }

        if let risk = business.keyRisks.first?.trimmingCharacters(in: .whitespacesAndNewlines), !risk.isEmpty {
            points.append(risk)
        }

        return Array(points.prefix(3))
    }
}
