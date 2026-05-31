import Foundation

/// Raw JSON captured from an API response, preserved for chat request bodies.
struct JSONPassThrough: Sendable {
    let data: Data
}

struct PortfolioFetchResult {
    let response: AccountPositionsResponse
    let accountPayload: JSONPassThrough
    let positionsPayload: JSONPassThrough
}

enum PortfolioPayloadExtractor {
    static func extract(from data: Data) throws -> (JSONPassThrough, JSONPassThrough) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decoding(NSError(domain: "PortfolioPayload", code: 1))
        }

        guard let accountObject = root["account"] else {
            throw APIError.decoding(NSError(domain: "PortfolioPayload", code: 2))
        }
        let accountData = try JSONSerialization.data(withJSONObject: accountObject)

        let schwabPositions = root["schwab_positions"] as? [String: Any] ?? [:]
        var flattened: [[String: Any]] = []
        for key in schwabPositions.keys.sorted() {
            if let items = schwabPositions[key] as? [[String: Any]] {
                flattened.append(contentsOf: items)
            }
        }
        let positionsData = try JSONSerialization.data(withJSONObject: flattened)

        return (JSONPassThrough(data: accountData), JSONPassThrough(data: positionsData))
    }
}
