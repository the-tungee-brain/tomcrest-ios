import SwiftUI

// MARK: - Hero snapshot

struct PortfolioSnapshotCard: View {
    let snapshot: AccountSnapshot
    let syncedAtLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net liquidation")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .textCase(.uppercase)

                    Text(CurrencyFormatter.usd(snapshot.liquidationValue, fractionDigits: 0))
                        .font(AppTypography.heroMetric)
                        .foregroundStyle(AppColors.label)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Open P/L")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text(CurrencyFormatter.signedUsd(snapshot.totalOpenProfitLoss ?? 0))
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(profitTone(snapshot.totalOpenProfitLoss ?? 0))
                }
            }

            AppMetricStrip(items: [
                ("Buying power", CurrencyFormatter.usd(snapshot.buyingPower, fractionDigits: 0)),
                ("Cash", CurrencyFormatter.usd(snapshot.cashBalance, fractionDigits: 0)),
                ("Positions", "\(snapshot.positionCount)"),
            ])

            if let syncedAtLabel {
                Text("Updated \(syncedAtLabel)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
        }
        .appHeroPanel()
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

// MARK: - Morning brief

struct MorningBriefCard: View {
    let lead: String?

    var body: some View {
        Text(lead ?? "Pull down to refresh for your morning brief.")
            .font(AppTypography.bodySecondary)
            .foregroundStyle(lead == nil ? AppColors.secondaryLabel : AppColors.label)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Plain text inside AppScreenSection("Today") — no nested panel border.
    }
}

// MARK: - Attention / alerts

struct PortfolioAlertsSection: View {
    let alerts: [ProactiveAlert]
    let attentionQueue: [AttentionItem]
    let onDismiss: (AttentionItem) -> Void

    var body: some View {
        Group {
            if !attentionQueue.isEmpty {
                AppGroupedList {
                    ForEach(Array(attentionQueue.prefix(5).enumerated()), id: \.element.id) { index, item in
                        AttentionRow(item: item, onDismiss: onDismiss)
                        if index < min(attentionQueue.count, 5) - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            } else if alerts.isEmpty {
                Text("No alerts right now.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appPanel(subtle: true)
            } else {
                AppGroupedList {
                    ForEach(Array(alerts.prefix(5).enumerated()), id: \.element.id) { index, alert in
                        AlertRow(alert: alert)
                        if index < min(alerts.count, 5) - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct AlertRow: View {
    let alert: ProactiveAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(alert.label)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                if let symbol = alert.symbol {
                    AppSymbolTag(symbol: symbol)
                }
            }
            Text(alert.reason)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct AttentionRow: View {
    let item: AttentionItem
    let onDismiss: (AttentionItem) -> Void

    var body: some View {
        AppListRow {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.label)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.label)
                    if let symbol = item.symbol {
                        AppSymbolTag(symbol: symbol)
                    }
                }
                Text(item.reason)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(2)
            }
        } trailing: {
            if item.alertId != nil {
                Button {
                    onDismiss(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss alert")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Holdings

struct HoldingsSection: View {
    let positions: [Position]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppGroupedList {
                ForEach(Array(positions.prefix(10).enumerated()), id: \.element.id) { index, position in
                    HoldingRow(position: position)
                    if index < min(positions.count, 10) - 1 {
                        AppGroupedDivider()
                    }
                }
            }

            if positions.count > 10 {
                Text("+ \(positions.count - 10) more positions")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .padding(.top, 10)
            }
        }
    }
}

private struct HoldingRow: View {
    let position: Position

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                SymbolAvatar(symbol: position.displaySymbol, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(position.displaySymbol)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.label)
                    Text(CurrencyFormatter.usd(position.marketValue, fractionDigits: 0))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 3) {
                Text(CurrencyFormatter.compactPercent(position.portfolioWeightPct))
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(AppColors.secondaryLabel)
                Text(CurrencyFormatter.signedUsd(position.openProfitLoss ?? 0))
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(profitTone(position.openProfitLoss ?? 0))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

// MARK: - Empty / connect states

struct SchwabConnectPrompt: View {
    var systemImage = "link.circle.fill"
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        AppEmptyState(
            systemImage: systemImage,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

// MARK: - Loading skeleton

struct PortfolioLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            skeletonBlock(height: 180)
            skeletonBlock(height: 96)
            skeletonBlock(height: 140)
        }
        .redacted(reason: .placeholder)
    }

    private func skeletonBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.secondaryBackground)
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
    }
}
