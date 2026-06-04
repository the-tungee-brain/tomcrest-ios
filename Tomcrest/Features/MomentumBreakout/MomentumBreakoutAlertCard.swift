import SwiftUI

struct MomentumBreakoutAlertCard: View {
    let alert: MomentumBreakoutAlertDto

    private var statusTone: MomentumBreakoutStatusBadgeTone {
        MomentumBreakoutAlertPresentation.statusBadgeTone(for: alert.lifecycleStatus)
    }

    private var riskTone: MomentumBreakoutRiskGateTone {
        MomentumBreakoutAlertPresentation.riskGateTone(action: alert.riskGateAction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            priceLevels
            statsGrid
            if alert.outcomeReturnPct != nil {
                outcomeRow
            }
            riskGateSection
            nextActionSection
        }
        .padding(14)
        .appPanel(subtle: true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.symbol.uppercased())
                    .font(AppTypography.monoCaptionSemibold)
                    .foregroundStyle(AppColors.label)
                Text(
                    "\(MomentumBreakoutAlertPresentation.formatSetupName(alert.setupName)) · \(alert.direction ?? "LONG") trade plan"
                )
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            }
            Spacer(minLength: 8)
            MomentumBreakoutStatusBadge(status: alert.lifecycleStatus)
        }
    }

    private var priceLevels: some View {
        HStack(spacing: 10) {
            priceCell(title: "Entry level", value: alert.entryPrice)
            priceCell(title: "Stop level", value: alert.stopPrice)
            priceCell(title: "Target level", value: alert.targetPrice)
        }
    }

    private func priceCell(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .tracking(0.4)
            Text(MomentumBreakoutAlertPresentation.formatUsd(value))
                .font(AppTypography.monoCaptionSemibold)
                .foregroundStyle(AppColors.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 8
        ) {
            statItem(title: "Risk / reward", value: MomentumBreakoutAlertPresentation.formatRiskReward(alert.riskReward))
            statItem(title: "Historical win rate", value: MomentumBreakoutAlertPresentation.formatWinRate(alert.historicalWinRate))
            statItem(title: "Profit factor", value: MomentumBreakoutAlertPresentation.formatProfitFactor(alert.historicalProfitFactor))
            statItem(title: "Historical trades", value: alert.historicalTotalTrades.map(String.init) ?? "—")
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(AppTypography.monoCaption)
                .foregroundStyle(AppColors.label)
        }
    }

    @ViewBuilder
    private var outcomeRow: some View {
        if let outcome = alert.outcomeReturnPct {
            Text("Outcome: \(String(format: "%.1f%%", outcome * 100))")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
    }

    @ViewBuilder
    private var riskGateSection: some View {
        let reasons = MomentumBreakoutAlertPresentation.filteredRiskReasons(alert.riskGateReasons ?? [])
        if riskTone != .normal || !reasons.isEmpty {
            let style = MomentumBreakoutAlertPresentation.riskGatePanelStyle(tone: riskTone)
            VStack(alignment: .leading, spacing: 6) {
                Text(MomentumBreakoutAlertPresentation.riskGateTitle(tone: riskTone))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.foreground)
                if !reasons.isEmpty {
                    ForEach(reasons, id: \.self) { reason in
                        Text("• \(reason)")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.background)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(style.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private var nextActionSection: some View {
        if let message = alert.nextActionMessage, !message.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT STEP")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .tracking(0.5)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.insetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
