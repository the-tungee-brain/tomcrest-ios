import Foundation

struct CashSecuredPutPosition: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let underlyingSymbol: String?
    let contracts: Double
    let strike: Double?
    let reservedCash: Double
}

struct CashSecuredPutSummary: Decodable {
    let totalReservedCash: Double
    let availableCashAfterReserves: Double?
    let positions: [CashSecuredPutPosition]
}

struct AssignmentRiskPosition: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let underlyingSymbol: String?
    let strategy: String?
    let putCall: String?
    let contracts: Double
    let strike: Double?
    let expiration: String?
    let daysToExpiration: Int?
    let underlyingPrice: Double?
    let moneyness: String?
    let riskLevel: String?
    let assignmentCashRequired: Double?
}

struct AssignmentRiskSummary: Decodable {
    let asOf: String?
    let withinDays: Int?
    let scopeSymbol: String?
    let positions: [AssignmentRiskPosition]
}

enum OptionsRiskHelpers {
    static func hasAssignmentRisk(_ summary: AssignmentRiskSummary?) -> Bool {
        !(summary?.positions.isEmpty ?? true)
    }

    static func filterAssignmentRisk(_ summary: AssignmentRiskSummary?, symbol: String) -> AssignmentRiskSummary? {
        guard let summary else { return nil }
        let upper = symbol.uppercased()
        let filtered = summary.positions.filter {
            ($0.underlyingSymbol ?? $0.symbol).uppercased() == upper
        }
        guard !filtered.isEmpty else { return nil }
        return AssignmentRiskSummary(
            asOf: summary.asOf,
            withinDays: summary.withinDays,
            scopeSymbol: upper,
            positions: filtered
        )
    }

    static func summarizeCSPCash(
        positions: [Position],
        cashBalance: Double?
    ) -> CashSecuredPutSummary? {
        var entries: [CashSecuredPutPosition] = []
        var total: Double = 0

        for position in positions where position.instrument.assetType == "OPTION" {
            guard position.longQuantity < 0 else { continue }
            let optionSymbol = position.instrument.symbol.uppercased()
            guard optionSymbol.contains("P") else { continue }
            let contracts = abs(position.longQuantity)
            let strike = parseStrike(from: position.instrument.symbol)
            let reserved = (strike ?? 0) * 100 * contracts
            guard reserved > 0 else { continue }
            total += reserved
            entries.append(
                CashSecuredPutPosition(
                    symbol: position.instrument.symbol,
                    underlyingSymbol: position.instrument.underlyingSymbol,
                    contracts: contracts,
                    strike: strike,
                    reservedCash: reserved
                )
            )
        }

        guard total > 0 else { return nil }
        let available = cashBalance.map { max($0 - total, 0) }
        return CashSecuredPutSummary(
            totalReservedCash: total,
            availableCashAfterReserves: available,
            positions: entries
        )
    }

    private static func parseStrike(from optionSymbol: String) -> Double? {
        let trimmed = optionSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return nil }
        let strikePart = String(trimmed.suffix(8))
        guard let raw = Double(strikePart) else { return nil }
        return raw / 1000
    }
}
