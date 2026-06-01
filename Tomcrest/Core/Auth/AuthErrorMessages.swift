import Foundation

extension String {
    var isAuthCancellationNoise: Bool {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "cancelled" || normalized == "canceled"
    }
}
