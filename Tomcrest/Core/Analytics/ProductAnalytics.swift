import Foundation

enum ProductAnalytics {
    static func track(_ event: String, properties: [String: String] = [:]) {
        #if DEBUG
        let payload = properties.isEmpty ? "" : " \(properties)"
        print("[analytics] \(event)\(payload)")
        #endif
    }
}
