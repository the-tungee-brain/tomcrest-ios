import SwiftUI

struct MomentumBreakoutInvestorBrief: View {
    let scan: MomentumBreakoutScanResponse?
    let paperSummary: PaperTradeSummaryDto?
    let loading: Bool
    let errorMessage: String?
    let trackedSymbols: Set<String>
    let onTrackPlan: ((String) async -> Void)?

    @State private var rejectedExpanded = false

    init(
        scan: MomentumBreakoutScanResponse?,
        paperSummary: PaperTradeSummaryDto?,
        loading: Bool,
        errorMessage: String?,
        trackedSymbols: Set<String> = [],
        onTrackPlan: ((String) async -> Void)? = nil
    ) {
        self.scan = scan
        self.paperSummary = paperSummary
        self.loading = loading
        self.errorMessage = errorMessage
        self.trackedSymbols = trackedSymbols
        self.onTrackPlan = onTrackPlan
    }

    private var partitioned: (
        tradable: [MomentumBreakoutScanCandidateDto],
        blocked: [MomentumBreakoutScanCandidateDto]
    ) {
        MomentumBreakoutInvestorCopy.partition(scan)
    }

    var body: some View {
        let hero = MomentumBreakoutInvestorCopy.buildHeroVerdict(
            scan: scan,
            tradable: partitioned.tradable,
            blocked: partitioned.blocked,
            loading: loading
        )
        let trackRecord = MomentumBreakoutInvestorCopy.deriveStrategyTrackRecord(
            paperSummary: paperSummary,
            scan: scan
        )
        let marketScan = MomentumBreakoutInvestorCopy.formatScanTimestamp(scan?.scanTime)
        let visibleRejected = rejectedExpanded
            ? partitioned.blocked
            : Array(partitioned.blocked.prefix(MomentumBreakoutInvestorCopy.rejectedPreviewCount))

        VStack(alignment: .leading, spacing: 16) {
            heroSection(hero, marketScan: marketScan)
            if let trackRecord {
                credibilitySection(trackRecord)
            }
            if !partitioned.tradable.isEmpty {
                tradableSection(partitioned.tradable)
            }
            rejectedSection(partitioned.blocked, visible: visibleRejected)
        }
    }

    private func heroSection(
        _ hero: MomentumBreakoutInvestorCopy.HeroVerdict,
        marketScan: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hero.title)
                .font(.title.weight(.bold))
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
            Text(hero.body)
                .font(.body)
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                heroStatChip(hero.stocksScanned, label: hero.stocksScanned == 1 ? "Stock scanned" : "Stocks scanned")
                heroStatChip(
                    hero.opportunitiesReviewed,
                    label: hero.opportunitiesReviewed == 1 ? "Opportunity reviewed" : "Opportunities reviewed"
                )
                heroStatChip(
                    hero.opportunitiesRejected,
                    label: hero.opportunitiesRejected == 1 ? "Opportunity rejected" : "Opportunities rejected"
                )
                if hero.opportunitiesApproved > 0 {
                    heroStatChip(
                        hero.opportunitiesApproved,
                        label: hero.opportunitiesApproved == 1 ? "Opportunity approved" : "Opportunities approved",
                        highlight: true
                    )
                }
            }
            Text(
                "We continue scanning automatically during market hours."
                + (marketScan.map { " Market scan: \($0)." } ?? "")
            )
            .font(.system(size: 13))
            .foregroundStyle(AppColors.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground(hero.tone))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.separator, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func heroStatChip(_ value: Int, label: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? AppColors.success : AppColors.label)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlight ? AppColors.success.opacity(0.1) : AppColors.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func heroBackground(_ tone: MomentumBreakoutInvestorCopy.MarketTone) -> Color {
        switch tone {
        case .favorable:
            return AppColors.success.opacity(0.08)
        case .cautious:
            return Color.orange.opacity(0.1)
        default:
            return AppColors.insetSurface
        }
    }

    private func credibilitySection(_ record: MomentumBreakoutInvestorCopy.StrategyTrackRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strategy Track Record")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.label)
            VStack(alignment: .leading, spacing: 10) {
                trackMetric("Win rate", MomentumBreakoutAlertPresentation.formatWinRate(record.winRate))
                trackMetric("Profit factor", MomentumBreakoutAlertPresentation.formatProfitFactor(record.profitFactor))
                trackMetric("Trades studied", record.tradesStudied.map(String.init) ?? "—")
            }
            Text("Based on historical pattern research. Future results may differ.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }

    private func trackMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.secondaryLabel)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.label)
        }
    }

    private func tradableSection(_ tradable: [MomentumBreakoutScanCandidateDto]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tradable Opportunities")
                .font(.system(size: 15, weight: .semibold))
            Text("Passed quality and risk checks. Tap Track to save this plan to your alert watchlist.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
            ForEach(tradable.prefix(8)) { candidate in
                let tracked = trackedSymbols.contains(candidate.symbol.uppercased())
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(candidate.symbol)
                            .font(.system(size: 17, weight: .bold))
                        Spacer()
                        Text("Approved")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.success)
                    }
                    Text(
                        "Entry \(MomentumBreakoutAlertPresentation.formatUsd(candidate.entryPrice)) · Stop \(MomentumBreakoutAlertPresentation.formatUsd(candidate.stopPrice)) · Target \(MomentumBreakoutAlertPresentation.formatUsd(candidate.targetPrice))"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.secondaryLabel)
                    if let onTrackPlan {
                        Button {
                            Task { await onTrackPlan(candidate.symbol) }
                        } label: {
                            Text(tracked ? "View on watchlist" : "Track this plan")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func rejectedSection(
        _ blocked: [MomentumBreakoutScanCandidateDto],
        visible: [MomentumBreakoutScanCandidateDto]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rejected Opportunities")
                .font(.system(size: 15, weight: .semibold))
            Text("Reviewed today but did not meet our standards.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
            if blocked.isEmpty {
                Text("No rejected opportunities in the latest scan window.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.secondaryLabel)
            } else {
                ForEach(visible) { candidate in
                    let reasons = MomentumBreakoutInvestorCopy.rejectedReasons(for: candidate)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.symbol)
                            .font(.system(size: 17, weight: .bold))
                        if let first = reasons.first {
                            Text(first)
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.secondaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(reasons.dropFirst()), id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.tertiaryLabel)
                        }
                        Text("No action recommended.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.tertiaryLabel)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.insetSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                if blocked.count > MomentumBreakoutInvestorCopy.rejectedPreviewCount {
                    Button {
                        rejectedExpanded.toggle()
                    } label: {
                        Text(
                            rejectedExpanded
                                ? "Show fewer"
                                : "Show all \(blocked.count) rejected opportunities"
                        )
                        .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.accentHighlight)
                }
            }
        }
    }
}
