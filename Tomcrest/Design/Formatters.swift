import Foundation

enum CurrencyFormatter {
    private static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    static func usd(_ value: Double, fractionDigits: Int = 2) -> String {
        currency.maximumFractionDigits = fractionDigits
        currency.minimumFractionDigits = fractionDigits
        return currency.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    static func signedUsd(_ value: Double) -> String {
        if value == 0 { return usd(0) }
        let formatted = usd(abs(value), fractionDigits: abs(value) >= 1000 ? 0 : 2)
        return value > 0 ? "+\(formatted)" : "-\(formatted)"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
    }

    static func compactPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value)
    }
}
