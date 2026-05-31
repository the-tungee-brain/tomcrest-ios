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

enum DateFormatters {
    private static let posix = Locale(identifier: "en_US_POSIX")

    private static let dateOnlyOutput: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = posix
        formatter.dateFormat = "MM-dd-yyyy"
        return formatter
    }()

    private static let dateTimeOutput: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = posix
        formatter.dateFormat = "MM-dd-yyyy HH:mm"
        return formatter
    }()

    /// MM-dd-yyyy, or MM-dd-yyyy HH:mm when the source includes a time.
    static func display(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }

        if !hasTimeComponent(in: trimmed),
           let dateOnly = reformattedISODatePrefix(trimmed) {
            return dateOnly
        }

        guard let date = parse(trimmed) else { return trimmed }
        return display(date, includeTime: hasTimeComponent(in: trimmed))
    }

    static func display(_ date: Date, includeTime: Bool = false) -> String {
        includeTime
            ? dateTimeOutput.string(from: date)
            : dateOnlyOutput.string(from: date)
    }

    /// Backward-compatible alias used across news, earnings, and activity rows.
    static func abbreviatedDay(from value: String) -> String {
        display(from: value)
    }

    static func parse(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate, .withDashSeparatorInDate],
        ] {
            iso.formatOptions = options
            if let date = iso.date(from: trimmed) { return date }
        }

        let datePrefix = String(trimmed.prefix(10))
        iso.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = iso.date(from: datePrefix) { return date }

        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "MM-dd-yyyy HH:mm", "MM-dd-yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = posix
            formatter.dateFormat = pattern
            if let date = formatter.date(from: trimmed) { return date }
        }

        return nil
    }

    private static func hasTimeComponent(in value: String) -> Bool {
        if value.contains("T") {
            let suffix = value.split(separator: "T", maxSplits: 1).dropFirst().first ?? ""
            return suffix.contains(":")
        }

        if value.range(of: #"^\d{4}-\d{2}-\d{2}\s+\d"#, options: .regularExpression) != nil {
            return true
        }

        if value.range(of: #"^\d{2}-\d{2}-\d{4}\s+\d{2}:\d{2}"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private static func reformattedISODatePrefix(_ value: String) -> String? {
        let prefix = String(value.prefix(10))
        guard prefix.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            return nil
        }

        let parts = prefix.split(separator: "-")
        guard parts.count == 3 else { return nil }
        return "\(parts[1])-\(parts[2])-\(parts[0])"
    }
}
