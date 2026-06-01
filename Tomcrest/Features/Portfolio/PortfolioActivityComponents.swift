import SwiftUI

// MARK: - Activity filters (web ActivityFilters)

private struct ActivityFilterChip: View {
    let title: String
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? AppColors.accentHighlight : AppColors.secondaryLabel)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.accentMuted : AppColors.secondaryFill)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? AppColors.accent.opacity(0.4) : AppColors.separator, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PortfolioActivityFilters: View {
    let daysBack: Int
    let symbolFilter: String?
    let activityBySymbol: [String: Int]
    let isDisabled: Bool
    let onDaysBackChange: (Int) -> Void
    let onSymbolFilterChange: (String?) -> Void

    private var symbolOptions: [(symbol: String, count: Int)] {
        activityBySymbol
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Period")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .frame(width: 52, alignment: .leading)

                HStack(spacing: 8) {
                    ForEach(RecentOrderFormatters.activityDayOptions, id: \.self) { days in
                        ActivityFilterChip(
                            title: "\(days)d",
                            isSelected: daysBack == days
                        ) {
                            onDaysBackChange(days)
                        }
                        .disabled(isDisabled)
                    }
                }
            }

            if !symbolOptions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Symbol")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .frame(width: 52, alignment: .leading)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ActivityFilterChip(
                                title: "All",
                                isSelected: symbolFilter == nil
                            ) {
                                onSymbolFilterChange(nil)
                            }
                            .disabled(isDisabled)

                            ForEach(symbolOptions, id: \.symbol) { option in
                                ActivityFilterChip(
                                    title: "\(option.symbol) (\(option.count))",
                                    isSelected: symbolFilter == option.symbol
                                ) {
                                    onSymbolFilterChange(option.symbol)
                                }
                                .disabled(isDisabled)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .background(AppColors.secondaryBackground.opacity(0.5))
    }
}

// MARK: - Activity section (web RecentActivitySection)

struct PortfolioActivitySection: View {
    let orders: [RecentOrderEntry]
    let totalOrders: Int
    let recentOrderCount: Int
    let daysBack: Int
    let symbolFilter: String?
    let activityBySymbol: [String: Int]
    let isLoading: Bool
    let errorMessage: String?
    let onDaysBackChange: (Int) -> Void
    let onSymbolFilterChange: (String?) -> Void
    let onSymbolTap: ((String) -> Void)?
    let onRetry: () -> Void

    private var displayGroups: [RecentOrderDisplayGroup] {
        RecentOrderFormatters.groupOrdersForDisplay(orders)
    }

    private var subtitle: String {
        RecentOrderFormatters.activitySubtitle(
            totalOrders: totalOrders,
            recentOrderCount: recentOrderCount,
            daysBack: daysBack,
            symbolFilter: symbolFilter
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            PortfolioActivityFilters(
                daysBack: daysBack,
                symbolFilter: symbolFilter,
                activityBySymbol: activityBySymbol,
                isDisabled: isLoading
            ) { days in
                onDaysBackChange(days)
            } onSymbolFilterChange: { symbol in
                onSymbolFilterChange(symbol)
            }

            if let errorMessage {
                AppInlineBanner(message: errorMessage, tone: .error)
                    .padding(.top, 12)
            }

            content
        }
        .appPanel()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .frame(width: 32, height: 32)
                .background(AppColors.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Recent trade activity")
                    .font(AppTypography.bodySecondary.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .background(AppColors.secondaryBackground.opacity(0.5))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading, orders.isEmpty {
            AppLoadingState(message: "Loading trade activity…")
                .padding(.vertical, 16)
        } else if orders.isEmpty {
            VStack(spacing: 8) {
                Text("No fills in this range")
                    .font(AppTypography.bodySecondary.weight(.medium))
                    .foregroundStyle(AppColors.label)
                Text(emptyDetail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .multilineTextAlignment(.center)

                if symbolFilter != nil {
                    Button("Clear symbol filter") {
                        onSymbolFilterChange(nil)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .padding(.top, 4)
                } else if errorMessage == nil {
                    Button("Retry") {
                        onRetry()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(displayGroups.enumerated()), id: \.element.id) { index, group in
                    switch group {
                    case let .roll(_, label, rollOrders):
                        VStack(alignment: .leading, spacing: 0) {
                            Text(label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.accentHighlight)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.accentMuted.opacity(0.35))

                            ForEach(Array(rollOrders.enumerated()), id: \.element.id) { rollIndex, order in
                                PortfolioActivityOrderRow(
                                    order: order,
                                    showRollBadge: false,
                                    onSymbolTap: onSymbolTap
                                )
                                if rollIndex < rollOrders.count - 1 {
                                    activityDivider
                                }
                            }
                        }

                    case let .single(order):
                        PortfolioActivityOrderRow(
                            order: order,
                            onSymbolTap: onSymbolTap
                        )
                    }

                    if index < displayGroups.count - 1 {
                        activityDivider
                    }
                }
            }
        }
    }

    private var activityDivider: some View {
        Divider().overlay(AppColors.separator)
    }

    private var emptyDetail: String {
        if let symbolFilter {
            return "No filled orders for \(symbolFilter) in the last \(daysBack) days."
        }
        return "No filled orders in the last \(daysBack) days."
    }
}

struct PortfolioActivityOrderRow: View {
    let order: RecentOrderEntry
    var showRollBadge: Bool = true
    var onSymbolTap: ((String) -> Void)?

    private var extraLegs: [RecentOrderLegEntry] {
        Array((order.legs ?? []).dropFirst())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    onSymbolTap?(order.symbol)
                } label: {
                    Text(order.symbol)
                        .font(AppTypography.monoSubheadlineSemibold)
                        .foregroundStyle(AppColors.label)
                }
                .buttonStyle(.plain)
                .disabled(onSymbolTap == nil)

                Spacer(minLength: 0)

                Text(RecentOrderFormatters.formatFillTime(order.fillTime))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            if let contract = RecentOrderFormatters.formatContractLabel(order) {
                Text(contract)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            if let badge = RecentOrderFormatters.formatStrategyBadge(order, showRollBadge: showRollBadge) {
                Text(badge)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.accentHighlight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.accentMuted)
                    .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(RecentOrderFormatters.formatSide(order.side))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)

                Spacer(minLength: 0)

                Text(tradeSummary)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .multilineTextAlignment(.trailing)
            }

            ForEach(extraLegs) { leg in
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(AppColors.separator)
                        .frame(width: 2)
                    Text(legSummary(leg))
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
                .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var tradeSummary: String {
        let qty = RecentOrderFormatters.formatQuantity(order.quantity, assetType: order.assetType)
        let price = RecentOrderFormatters.formatFillPrice(order.averageFillPrice, assetType: order.assetType)
        if let total = order.totalCash {
            return "\(qty) @ \(price) (\(RecentOrderFormatters.formatTotalCash(total)) total)"
        }
        return "\(qty) @ \(price)"
    }

    private func legSummary(_ leg: RecentOrderLegEntry) -> String {
        let side = RecentOrderFormatters.formatSide(leg.instruction)
        let contract = RecentOrderFormatters.formatLegContractLabel(leg) ?? "Leg"
        let qty = RecentOrderFormatters.formatQuantity(leg.quantity, assetType: leg.assetType)
        let price = RecentOrderFormatters.formatFillPrice(leg.averageFillPrice, assetType: leg.assetType)
        return "\(side) · \(contract) · \(qty) @ \(price)"
    }
}
