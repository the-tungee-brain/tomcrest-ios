import Foundation

enum RecentOrderDisplayGroup: Identifiable {
    case roll(id: String, label: String, orders: [RecentOrderEntry])
    case single(RecentOrderEntry)

    var id: String {
        switch self {
        case let .roll(id, _, _):
            id
        case let .single(order):
            order.id
        }
    }
}

enum RecentOrderFormatters {
    static let activityDayOptions = [7, 30, 60]

    static func groupOrdersForDisplay(_ orders: [RecentOrderEntry]) -> [RecentOrderDisplayGroup] {
        var seenRollGroups = Set<String>()
        var groups: [RecentOrderDisplayGroup] = []

        for order in orders {
            if order.activityGroupKind == "roll", let groupId = order.activityGroupId {
                guard seenRollGroups.insert(groupId).inserted else { continue }
                let rollOrders = orders.filter { $0.activityGroupId == groupId }
                groups.append(
                    .roll(
                        id: groupId,
                        label: order.activityGroupLabel ?? "Option roll",
                        orders: rollOrders
                    )
                )
                continue
            }
            groups.append(.single(order))
        }

        return groups
    }

    static func formatSide(_ side: String) -> String {
        side
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }

    static func formatFillTime(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return DateFormatters.display(from: value)
    }

    static func formatContractLabel(_ order: RecentOrderEntry) -> String? {
        order.contractLabel
    }

    static func formatLegContractLabel(_ leg: RecentOrderLegEntry) -> String? {
        leg.contractLabel
    }

    static func formatStrategyBadge(_ order: RecentOrderEntry, showRollBadge: Bool = true) -> String? {
        if showRollBadge,
           order.activityGroupKind == "roll",
           let label = order.activityGroupLabel {
            return label
        }
        return order.strategyLabel
    }

    private static func isOption(_ assetType: String?) -> Bool {
        assetType == "OPTION"
    }

    private static func isEquity(_ assetType: String?) -> Bool {
        assetType == "EQUITY"
    }

    static func formatQuantity(_ quantity: Double?, assetType: String?) -> String {
        guard let quantity else { return "—" }
        let whole = quantity.truncatingRemainder(dividingBy: 1) == 0
        let qty = whole ? String(format: "%.0f", quantity) : String(quantity)
        if isOption(assetType) { return "\(qty) ct" }
        if isEquity(assetType) { return "\(qty) sh" }
        return qty
    }

    static func formatFillPrice(_ price: Double?, assetType: String?) -> String {
        guard let price else { return "—" }
        let formatted = CurrencyFormatter.usd(price)
        if isOption(assetType) { return "\(formatted)/ct" }
        if isEquity(assetType) { return "\(formatted)/sh" }
        return formatted
    }

    static func formatTotalCash(_ value: Double?) -> String {
        guard let value else { return "—" }
        return CurrencyFormatter.usd(value)
    }

    static func activitySubtitle(
        totalOrders: Int,
        recentOrderCount: Int,
        daysBack: Int,
        symbolFilter: String?
    ) -> String {
        let scope = symbolFilter.map { "\($0) · " } ?? ""
        if recentOrderCount > 0, daysBack > 7, symbolFilter == nil {
            return "\(recentOrderCount) in the last 7 days · \(totalOrders) total · \(scope)last \(daysBack) days"
        }
        let noun = totalOrders == 1 ? "order" : "orders"
        return "\(totalOrders) filled \(noun) · \(scope)last \(daysBack) days"
    }
}
