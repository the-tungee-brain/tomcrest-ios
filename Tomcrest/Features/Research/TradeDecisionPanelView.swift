import SwiftUI

struct TradeDecisionPanelView: View {
    let symbol: String
    let accessToken: String?

    @State private var decision: TradeDecision?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        AppScreenSection(
            title: "Execution Readiness",
            footnote: "Answers whether the setup is actionable now"
        ) {
            if isLoading, decision == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let errorMessage, decision == nil {
                AppInlineBanner(message: errorMessage, tone: .error)
            } else if let decision {
                content(decision)
            } else {
                AppEmptyMessage(message: "Execution readiness is not available.")
            }
        }
        .task(id: symbol) {
            await load()
        }
    }

    @ViewBuilder
    private func content(_ decision: TradeDecision) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                metricPill(
                    title: "Regime",
                    value: decision.regime.tradeEnvironment.rawValue.capitalized,
                    sub: decision.regime.regimeId,
                    valueColor: regimeColor(decision.regime.tradeEnvironment)
                )
                metricPill(
                    title: "Setup quality",
                    value: "\(decision.tradeQualityScore) / 100",
                    sub: nil,
                    valueColor: scoreColor(decision.tradeQualityScore)
                )
                metricPill(
                    title: "Execution gate",
                    value: bucketLabel(decision.scoreBucket),
                    sub: nil,
                    valueColor: bucketColor(decision.scoreBucket)
                )
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IS IT ACTIONABLE NOW?")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                    Text(readinessLabel(decision.verdict))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(verdictColor(decision.verdict))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ACTION")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                    Text(actionLabel(decision.action))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(actionColor(decision.action))
                }
            }
            .padding(12)
            .background(verdictColor(decision.verdict).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            reasonBreakdown(decision.reasonBreakdown)
        }
        .appPanel(subtle: true)
    }

    @ViewBuilder
    private func reasonBreakdown(_ breakdown: TradeDecisionReasonBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REASON BREAKDOWN")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)

            if !breakdown.hardBlockers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hard blockers")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.danger)
                    ForEach(breakdown.hardBlockers, id: \.self) { line in
                        Text("• \(line)")
                            .font(.caption)
                            .foregroundStyle(AppColors.label)
                    }
                }
            }

            if let weakness = breakdown.primaryWeakness, !weakness.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Primary weakness")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text("• \(weakness)")
                        .font(.caption)
                        .foregroundStyle(AppColors.label)
                }
            }

            if !breakdown.secondaryFactors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secondary factors")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                    ForEach(breakdown.secondaryFactors, id: \.self) { line in
                        Text("• \(line)")
                            .font(.caption)
                            .foregroundStyle(AppColors.label)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryFill.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metricPill(
        title: String,
        value: String,
        sub: String?,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(valueColor)
            if let sub, !sub.isEmpty {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(AppColors.secondaryFill.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func bucketLabel(_ bucket: ScoreBucket) -> String {
        switch bucket {
        case .trade: "Trade"
        case .setup: "Setup"
        case .watchlist: "Watchlist"
        case .noTrade: "No trade"
        }
    }

    private func readinessLabel(_ verdict: TradeVerdict) -> String {
        switch verdict {
        case .trade: "Actionable"
        case .watchlist: "Wait for setup"
        case .noTrade: "Not actionable"
        }
    }

    private func actionLabel(_ action: TradeAction) -> String {
        switch action {
        case .enter: "Enter"
        case .waitForSetup: "Wait for setup"
        case .avoid: "Avoid"
        }
    }

    private func verdictColor(_ verdict: TradeVerdict) -> Color {
        switch verdict {
        case .trade: AppColors.success
        case .watchlist: AppColors.label
        case .noTrade: AppColors.danger
        }
    }

    private func actionColor(_ action: TradeAction) -> Color {
        switch action {
        case .enter: AppColors.success
        case .waitForSetup: AppColors.secondaryLabel
        case .avoid: AppColors.danger
        }
    }

    private func bucketColor(_ bucket: ScoreBucket) -> Color {
        switch bucket {
        case .trade: AppColors.success
        case .setup: AppColors.accentHighlight
        case .watchlist: AppColors.label
        case .noTrade: AppColors.danger
        }
    }

    private func regimeColor(_ env: TradeEnvironment) -> Color {
        switch env {
        case .favorable: AppColors.success
        case .neutral: AppColors.label
        case .avoid: AppColors.danger
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 60 { return AppColors.accentHighlight }
        if score >= 40 { return AppColors.label }
        return AppColors.danger
    }

    private func load() async {
        guard let accessToken, !accessToken.isEmpty else {
            errorMessage = "Sign in to view execution readiness."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            decision = try await ResearchService.fetchTradeDecision(
                symbol: symbol,
                accessToken: accessToken
            )
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            decision = nil
        }
    }
}
