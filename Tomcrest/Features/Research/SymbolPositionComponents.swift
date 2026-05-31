import SwiftUI

enum PositionFormatters {
    static func legLabel(_ position: Position) -> String {
        if position.instrument.assetType == "OPTION" {
            return position.instrument.description ?? position.instrument.symbol
        }
        if let description = position.instrument.description, !description.isEmpty {
            return description
        }
        return position.instrument.symbol
    }

    static func assetTypeLabel(_ assetType: String) -> String? {
        switch assetType.uppercased() {
        case "OPTION": "Option"
        case "EQUITY": nil
        case "ETF": "ETF"
        case "MUTUAL_FUND": "Fund"
        default: AssetTypeLabel.display(assetType)
        }
    }

    static func quantityLabel(_ position: Position) -> String {
        let qty = position.longQuantity
        let whole = qty.truncatingRemainder(dividingBy: 1) == 0
        let formatted = whole ? String(format: "%.0f", qty) : String(qty)
        if position.instrument.assetType == "OPTION" {
            return "\(formatted) ct"
        }
        return formatted
    }

    static func openProfitLossText(_ position: Position) -> String {
        let value = position.openProfitLoss ?? 0
        var text = CurrencyFormatter.signedUsd(value)
        if let pct = position.openProfitLossPct {
            text += " (\(String(format: "%.1f%%", pct)))"
        }
        return text
    }
}

// MARK: - Position legs (web SymbolLegsTable + AnalysisPanel KPI header)

struct SymbolPositionLegsSection: View {
    let symbol: String
    let positions: [Position]

    private var totalValue: Double { PositionMetrics.totalValue(positions) }
    private var openPL: Double { PositionMetrics.totalOpenProfitLoss(positions) }
    private var dayPL: Double { PositionMetrics.totalDayProfitLoss(positions) }
    private var openPLPct: Double? { PositionMetrics.openProfitLossPct(positions) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .frame(width: 32, height: 32)
                        .background(AppColors.accentMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Holdings")
                            .font(AppTypography.bodySecondary.weight(.semibold))
                            .foregroundStyle(AppColors.label)
                        Text(legSubtitle)
                            .font(.caption2)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }

                    Spacer(minLength: 0)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    alignment: .leading,
                    spacing: 8
                ) {
                    kpiTile("Value", CurrencyFormatter.usd(totalValue, fractionDigits: 0))
                    kpiTile(
                        "Open P/L",
                        openPLText,
                        tone: profitTone(openPL)
                    )
                    kpiTile(
                        "Today",
                        CurrencyFormatter.signedUsd(dayPL),
                        tone: profitTone(dayPL)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.secondaryBackground.opacity(0.5))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: 1)
            }

            ForEach(Array(positions.enumerated()), id: \.element.id) { index, position in
                SymbolPositionLegRow(position: position)
                if index < positions.count - 1 {
                    AppGroupedDivider()
                }
            }
        }
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private var legSubtitle: String {
        let legLabel = positions.count == 1 ? "1 leg" : "\(positions.count) legs"
        return "\(legLabel) · \(symbol) holdings"
    }

    private var openPLText: String {
        var text = CurrencyFormatter.signedUsd(openPL)
        if let openPLPct {
            let sign = openPLPct >= 0 ? "+" : ""
            text += " (\(sign)\(String(format: "%.1f%%", openPLPct)))"
        }
        return text
    }

    private func kpiTile(_ label: String, _ value: String, tone: Color = AppColors.label) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(tone)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.surfaceElevated.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

struct SymbolPositionLegRow: View {
    let position: Position

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(PositionFormatters.legLabel(position))
                    .font(AppTypography.bodySecondary.weight(.medium))
                    .foregroundStyle(AppColors.label)
                    .multilineTextAlignment(.leading)

                if let typeLabel = PositionFormatters.assetTypeLabel(position.instrument.assetType) {
                    Text(typeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accentMuted)
                        .clipShape(Capsule())
                }
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 10
            ) {
                metricTile("Qty", PositionFormatters.quantityLabel(position))
                metricTile("Value", CurrencyFormatter.usd(position.marketValue, fractionDigits: 0))
                metricTile("Open P/L", PositionFormatters.openProfitLossText(position), tone: profitTone(position.openProfitLoss ?? 0))
                metricTile(
                    "Today",
                    CurrencyFormatter.signedUsd(position.currentDayProfitLoss),
                    tone: profitTone(position.currentDayProfitLoss)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func metricTile(_ label: String, _ value: String, tone: Color = AppColors.label) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(tone)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

// MARK: - Tax & proactive alerts (web TaxWashSaleStrip, SymbolAlertStrip)

struct SymbolTaxWashSaleStrip: View {
    let items: [TaxAlertItem]
    let onReview: (TaxAlertItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xfbbf24))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: 0xf59e0b, opacity: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tax & wash-sale watch")
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text("Recent sell/buy pairs that may affect tax lots")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: 0xf59e0b, opacity: 0.05))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(hex: 0xf59e0b, opacity: 0.2))
                    .frame(height: 1)
            }

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.label)
                                .font(AppTypography.bodySecondary.weight(.medium))
                                .foregroundStyle(AppColors.label)
                            if let symbol = item.symbol {
                                Text(symbol)
                                    .font(.caption.weight(.semibold).monospaced())
                                    .foregroundStyle(AppColors.accentHighlight)
                            }
                        }
                        Text(item.reason)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }

                    Button {
                        onReview(item)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "scalemass")
                                .font(.caption.weight(.semibold))
                            Text("Review tax angle")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(AppColors.accentHighlight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppColors.separator, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if index < items.count - 1 {
                    Divider().overlay(AppColors.separator)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xf59e0b, opacity: 0.3), lineWidth: 1)
        }
    }
}

struct SymbolAlertStrip: View {
    let symbol: String
    let alerts: [ProactiveAlert]
    let onRunAlert: (ProactiveAlert) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Suggested for \(symbol.uppercased())")
                    .font(AppTypography.bodySecondary.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text("Proactive alerts based on your holdings and expiring options")
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.secondaryBackground.opacity(0.5))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: 1)
            }

            VStack(spacing: 8) {
                ForEach(alerts) { alert in
                    Button {
                        onRunAlert(alert)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: alertIcon(for: alert))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.accentHighlight)
                                Text(alert.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.label)
                            }
                            Text(alert.reason)
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.separator, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private func alertIcon(for alert: ProactiveAlert) -> String {
        switch IntelligenceHelpers.alertToQuickActionId(alert) {
        case "assignment-risk": "timer"
        case "risk-check": "shield.lefthalf.filled"
        case "what-changed": "questionmark.circle"
        case "tax-angle": "scalemass"
        default: "sparkles"
        }
    }
}

struct SymbolSuggestedActionChips: View {
    let actions: [SuggestedAnalysisAction]
    let onSelect: (SuggestedAnalysisAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested analysis")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(actions) { action in
                    Button {
                        onSelect(action)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: chipIcon(for: action))
                                .font(.caption2.weight(.semibold))
                            Text(action.label)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppColors.label)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.background)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppColors.separator, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(action.reason)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1)
        }
    }

    private func chipIcon(for action: SuggestedAnalysisAction) -> String {
        switch IntelligenceHelpers.suggestedActionToQuickActionId(action.action) {
        case "risk-check": "shield.lefthalf.filled"
        case "what-changed": "questionmark.circle"
        case "daily-summary": "calendar"
        default: "sparkles"
        }
    }
}

// MARK: - Symbol recent trades (web RecentActivitySection compact)

struct SymbolRecentActivitySection: View {
    let symbol: String
    let orders: [RecentOrderEntry]
    let suggestedActions: [SuggestedAnalysisAction]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onSuggestedAction: (SuggestedAnalysisAction) -> Void

    private var displayGroups: [RecentOrderDisplayGroup] {
        RecentOrderFormatters.groupOrdersForDisplay(orders)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .frame(width: 32, height: 32)
                    .background(AppColors.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(symbol.uppercased()) recent trades")
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text("\(orders.count) filled orders · last 30 days")
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

            if let errorMessage {
                AppInlineBanner(message: errorMessage, tone: .error)
                    .padding(.top, 12)
            }

            if isLoading, orders.isEmpty {
                AppLoadingState(message: "Loading recent trades…")
                    .padding(.vertical, 16)
            } else if orders.isEmpty {
                Text("No filled orders in the last 30 days.")
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
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
                                    PortfolioActivityOrderRow(order: order, showRollBadge: false)
                                    if rollIndex < rollOrders.count - 1 {
                                        activityDivider
                                    }
                                }
                            }

                        case let .single(order):
                            PortfolioActivityOrderRow(order: order, showRollBadge: true)
                        }

                        if index < displayGroups.count - 1 {
                            activityDivider
                        }
                    }
                }
            }

            if !suggestedActions.isEmpty {
                SymbolSuggestedActionChips(actions: suggestedActions, onSelect: onSuggestedAction)
            }

            if errorMessage != nil, orders.isEmpty {
                Button("Retry", action: onRetry)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .padding(.vertical, 16)
            }
        }
        .appPanel()
    }

    private var activityDivider: some View {
        Divider().overlay(AppColors.separator)
    }
}
