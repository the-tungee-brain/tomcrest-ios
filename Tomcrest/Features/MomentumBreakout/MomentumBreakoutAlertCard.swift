import SwiftUI

struct MomentumBreakoutAlertCard: View {
    let alert: MomentumBreakoutAlertDto

    @State private var statsOpen = false

    private var verdict: MomentumBreakoutInvestorCopy.AlertVerdict {
        MomentumBreakoutInvestorCopy.deriveAlertVerdict(alert)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            verdictHeader
            Text("Status: \(MomentumBreakoutAlertPresentation.statusLabel(for: alert.lifecycleStatus))")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
            priceStrip
            if let message = alert.nextActionMessage, !message.isEmpty {
                Text("Next: \(message)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if alert.outcomeReturnPct != nil {
                outcomeRow
            }
            optionalDetailSection
        }
        .padding(12)
        .appPanel(subtle: true)
        .id(MomentumBreakoutInvestorCopy.alertElementId(symbol: alert.symbol))
    }

    private var verdictHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(alert.symbol.uppercased())
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.label)
            Text(verdict.kind.rawValue)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(verdictColor)
            Text(verdict.explanation)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(verdictBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var verdictColor: Color {
        switch verdict.kind {
        case .approved: AppColors.success
        case .caution: .orange
        case .rejected: AppColors.error
        case .completed: AppColors.secondaryLabel
        }
    }

    private var verdictBackground: Color {
        switch verdict.kind {
        case .approved: AppColors.success.opacity(0.08)
        case .caution: Color.orange.opacity(0.1)
        case .rejected: AppColors.error.opacity(0.08)
        case .completed: AppColors.insetSurface
        }
    }

    private var priceStrip: some View {
        Text(priceStripText)
            .font(.system(size: 15))
            .foregroundStyle(AppColors.label)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var priceStripText: String {
        let entry = MomentumBreakoutAlertPresentation.formatUsd(alert.entryPrice)
        let stop = MomentumBreakoutAlertPresentation.formatUsd(alert.stopPrice)
        let target = MomentumBreakoutAlertPresentation.formatUsd(alert.targetPrice)
        return "Entry \(entry) · Stop \(stop) · Target \(target)"
    }

    @ViewBuilder
    private var optionalDetailSection: some View {
        DisclosureGroup(isExpanded: $statsOpen) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 8
            ) {
                detailStat("Reward vs risk", MomentumBreakoutAlertPresentation.formatRiskReward(alert.riskReward))
                detailStat("Past win rate", MomentumBreakoutAlertPresentation.formatWinRate(alert.historicalWinRate))
                detailStat("Past profit factor", MomentumBreakoutAlertPresentation.formatProfitFactor(alert.historicalProfitFactor))
                detailStat("Past examples", alert.historicalTotalTrades.map(String.init) ?? "—")
            }
            .padding(.top, 4)
        } label: {
            Text("More detail (optional)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.secondaryLabel)
        }
    }

    private func detailStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.secondaryLabel)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.label)
        }
    }

    @ViewBuilder
    private var outcomeRow: some View {
        if let outcome = alert.outcomeReturnPct {
            Text("Result when closed: \(String(format: "%.1f%%", outcome * 100))")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
        }
    }
}

struct MomentumBreakoutStatusBadge: View {
    let status: MomentumBreakoutLifecycleStatus

    var body: some View {
        let tone = MomentumBreakoutAlertPresentation.statusBadgeTone(for: status)
        let colors = MomentumBreakoutAlertPresentation.statusBadgeColors(tone: tone)
        Text(MomentumBreakoutAlertPresentation.statusLabel(for: status))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(colors.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colors.background)
            .overlay {
                Capsule().stroke(colors.border, lineWidth: 1)
            }
            .clipShape(Capsule())
    }
}
