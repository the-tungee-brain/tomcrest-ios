import SwiftUI

// MARK: - Hero summary (main dashboard only)

struct PortfolioHeroSummary: View {
    let liquidationValue: Double
    let totalDayProfitLoss: Double
    let totalOpenProfitLoss: Double
    let openProfitLossPct: Double?
    let cashBalance: Double
    let syncedAtLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Total value")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .textCase(.uppercase)

                Text(CurrencyFormatter.usd(liquidationValue, fractionDigits: 0))
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.label)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                profitChip(label: "Today", value: totalDayProfitLoss)
                profitChip(
                    label: "Open",
                    value: totalOpenProfitLoss,
                    percent: openProfitLossPct
                )
            }

            HStack(spacing: 16) {
                metricInline("Cash", CurrencyFormatter.usd(cashBalance, fractionDigits: 0))
                if let syncedAtLabel {
                    Text("Updated \(syncedAtLabel)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private func profitChip(label: String, value: Double, percent: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            HStack(spacing: 6) {
                Text(CurrencyFormatter.signedUsd(value))
                    .font(AppTypography.monoSubheadlineSemibold)
                    .foregroundStyle(profitTone(value))

                if let percent {
                    Text(CurrencyFormatter.percent(percent))
                        .font(AppTypography.monoCaption2Medium)
                        .foregroundStyle(profitTone(percent))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.insetSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricInline(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(AppTypography.monoCaptionSemibold)
                .foregroundStyle(AppColors.secondaryLabel)
        }
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

// MARK: - Brief preview

struct PortfolioBriefPreview: View {
    let lead: String?
    let isUrgent: Bool
    let attentionCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: isUrgent ? "exclamationmark.circle.fill" : "sun.max.fill")
                    .foregroundStyle(isUrgent ? AppColors.warning : AppColors.accentHighlight)
                Text("Morning brief")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Spacer()
                if attentionCount > 0 {
                    Text("\(attentionCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.onAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppColors.warning)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
            }

            Text(previewText)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineLimit(2)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private var previewText: String {
        if let lead, !lead.isEmpty { return lead }
        return "Tap for today's briefing, alerts, and playbook."
    }
}

// MARK: - Quick links

struct PortfolioQuickLinkRow: View {
    let icon: String
    var iconTint: Color = AppColors.accentHighlight
    let title: String
    var subtitle: String?
    var badge: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 30, height: 30)
                .background(iconTint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppColors.label)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }

            Spacer(minLength: 8)

            if badge > 0 {
                Text("\(badge)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.onAccent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
    }
}

// MARK: - Compact holdings

struct PortfolioCompactHoldingsList: View {
    let summaries: [SymbolHoldingSummary]
    var onSymbolTap: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                Button {
                    onSymbolTap(summary.symbol)
                } label: {
                    PortfolioCompactHoldingRow(summary: summary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < summaries.count - 1 {
                    Divider().overlay(AppColors.separator).padding(.leading, 56)
                }
            }
        }
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }
}

private struct PortfolioCompactHoldingRow: View {
    let summary: SymbolHoldingSummary

    var body: some View {
        HStack(spacing: 12) {
            SymbolAvatar(symbol: summary.symbol, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(CurrencyFormatter.compactPercent(summary.weightPct))
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(CurrencyFormatter.usd(summary.marketValue, fractionDigits: 0))
                    .font(AppTypography.monoSubheadlineMedium)
                    .foregroundStyle(AppColors.label)
                Text(CurrencyFormatter.signedUsd(summary.dayProfitLoss))
                    .font(AppTypography.monoCaptionSemibold)
                    .foregroundStyle(profitTone(summary.dayProfitLoss))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}
