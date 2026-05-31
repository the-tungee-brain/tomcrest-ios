import Foundation

/// Raw JSON captured from an API response, preserved for chat request bodies.
struct JSONPassThrough: Sendable {
    let data: Data
}

/// `JSONSerialization` only accepts Foundation types. Swift `Bool` in `[String: Any]` crashes.
enum JSONBodyEncoding {
    static func data(from object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: foundationObject(object))
    }

    private static func foundationObject(_ value: Any) -> Any {
        switch value {
        case let bool as Bool:
            return NSNumber(value: bool)
        case let number as Int:
            return NSNumber(value: number)
        case let number as Int64:
            return NSNumber(value: number)
        case let number as Double:
            return NSNumber(value: number)
        case let number as Float:
            return NSNumber(value: number)
        case let string as String:
            return string
        case is NSNull:
            return NSNull()
        case let dictionary as [String: Any]:
            return dictionary.mapValues { foundationObject($0) }
        case let array as [Any]:
            return array.map { foundationObject($0) }
        default:
            return value
        }
    }
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
