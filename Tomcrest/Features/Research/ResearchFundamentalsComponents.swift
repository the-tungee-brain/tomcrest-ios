import SwiftUI

// MARK: - Valuation-focused fundamentals (web FundamentalsPageContent)

struct ValuationSignalsGrid: View {
    let signals: [ValuationSignal]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(signals) { signal in
                VStack(alignment: .leading, spacing: 4) {
                    Text(signal.label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .tracking(0.3)
                    Text(signal.value)
                        .font(AppTypography.cardTitle.monospacedDigit())
                        .foregroundStyle(AppColors.label)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(AppColors.secondaryFill.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

struct FundamentalsValuationSection: View {
    let overview: FundamentalsOverview?

    var body: some View {
        if let overview {
            VStack(alignment: .leading, spacing: 16) {
                if !overview.valuationConclusion.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VALUATION CONCLUSION")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .tracking(0.4)
                        Text(overview.valuationConclusion)
                            .font(AppTypography.bodySecondary.weight(.medium))
                            .foregroundStyle(AppColors.label)
                            .lineSpacing(4)
                    }
                }

                if !overview.investmentThesis.bullCase.isEmpty
                    || !overview.investmentThesis.bearCase.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("INVESTMENT THESIS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .tracking(0.4)

                        HStack(alignment: .top, spacing: 12) {
                            thesisColumn(
                                title: "Bull case",
                                items: overview.investmentThesis.bullCase,
                                tone: .success
                            )
                            thesisColumn(
                                title: "Bear case",
                                items: overview.investmentThesis.bearCase,
                                tone: .danger
                            )
                        }
                    }
                }

                if !overview.valuationSummary.isEmpty,
                   overview.valuationSummary != overview.valuationConclusion {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WHAT IS PRICED IN")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .tracking(0.4)
                        Text(overview.valuationSummary)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(3)
                    }
                }

                if let street = overview.streetContext, !street.isEmpty {
                    Text(street)
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .lineSpacing(3)
                }
            }
            .appPanel(subtle: true)
        }
    }

    @ViewBuilder
    private func thesisColumn(
        title: String,
        items: [String],
        tone: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tone)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.label)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Wall Street analysis (web StreetAnalysisSection)

struct StreetAnalysisSection: View {
    let street: StreetAnalysisSnapshot?

    var body: some View {
        if StreetAnalysisFormatters.hasStreetAnalysis(street), let street {
            VStack(alignment: .leading, spacing: 16) {
                if street.consensusLabel != nil || street.recommendation != nil {
                    consensusBlock(street)
                }

                if let targets = street.priceTargets,
                   targets.mean != nil || targets.low != nil || targets.high != nil {
                    priceTargetsBlock(targets)
                }

                if let headline = street.ratingTrendHeadline ?? street.growthContextHeadline {
                    Text(headline)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.label)
                        .lineSpacing(3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.accentMuted.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let actions = street.recentRatingActions, !actions.isEmpty {
                    recentActionsBlock(actions)
                }

                Text(StreetAnalysisFormatters.attribution(dataAsOf: street.dataAsOf))
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
            .appPanel(subtle: true)
        } else {
            Text("Analyst consensus and price targets aren't available for this symbol.")
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appPanel(subtle: true)
        }
    }

    @ViewBuilder
    private func consensusBlock(_ street: StreetAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("ANALYST CONSENSUS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .tracking(0.4)

                if let label = street.consensusLabel {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accentMuted)
                        .clipShape(Capsule())
                }
            }

            if let recommendation = street.recommendation, recommendation.total > 0 {
                RecommendationBar(recommendation: recommendation)
            }
        }
    }

    @ViewBuilder
    private func priceTargetsBlock(_ targets: AnalystPriceTargets) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRICE VS STREET")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .tracking(0.4)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 8
            ) {
                targetTile("Current", StreetAnalysisFormatters.formatPrice(targets.current))
                targetTile("Mean target", StreetAnalysisFormatters.formatPrice(targets.mean))
                targetTile(
                    "Vs mean",
                    StreetAnalysisFormatters.formatPremiumDiscountToTarget(
                        current: targets.current,
                        mean: targets.mean,
                        upsideToMeanPct: targets.upsideToMeanPct
                    )
                )
            }

            if targets.upsideToMeanPct != nil {
                Text(
                    "Implied upside to mean target: \(StreetAnalysisFormatters.formatUpside(targets.upsideToMeanPct))"
                )
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 8
            ) {
                targetTile("Low", StreetAnalysisFormatters.formatPrice(targets.low))
                targetTile("High", StreetAnalysisFormatters.formatPrice(targets.high))
            }
        }
    }

    private func targetTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(AppTypography.cardTitle.monospacedDigit())
                .foregroundStyle(AppColors.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.secondaryFill.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.separator, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func recentActionsBlock(_ actions: [AnalystRatingAction]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT ANALYST ACTIONS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .tracking(0.4)

            ForEach(Array(actions.prefix(5))) { action in
                HStack(alignment: .top, spacing: 8) {
                    Text(StreetAnalysisFormatters.formatActionDate(action.date))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .frame(width: 52, alignment: .leading)

                    Text(StreetAnalysisFormatters.formatRatingActionLine(action))
                        .font(.caption)
                        .foregroundStyle(AppColors.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct RecommendationBar: View {
    let recommendation: RecommendationBreakdown

    private struct Segment {
        let label: String
        let count: Int
        let color: Color
    }

    private var segments: [Segment] {
        [
            Segment(label: "Strong buy", count: recommendation.strongBuy, color: AppColors.accent),
            Segment(label: "Buy", count: recommendation.buy, color: AppColors.accent.opacity(0.7)),
            Segment(label: "Hold", count: recommendation.hold, color: AppColors.secondaryLabel.opacity(0.5)),
            Segment(label: "Sell", count: recommendation.sell, color: AppColors.warning.opacity(0.7)),
            Segment(label: "Strong sell", count: recommendation.strongSell, color: AppColors.error),
        ].filter { $0.count > 0 }
    }

    var body: some View {
        let total = max(recommendation.total, 1)

        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        segment.color
                            .frame(width: max(2, proxy.size.width * CGFloat(segment.count) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Text("\(segment.label) \(segment.count)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        }
    }
}

// MARK: - Ownership (web StreetOwnershipSection)

struct StreetOwnershipSection: View {
    let ownership: OwnershipSnapshot?
    let dataAsOf: String?

    @State private var showAllInsiderTx = false

    private let insiderPreviewLimit = 5

    var body: some View {
        if StreetAnalysisFormatters.hasOwnership(ownership), let ownership {
            VStack(alignment: .leading, spacing: 16) {
                if ownership.insidersPctHeld != nil || ownership.institutionsPctHeld != nil {
                    HStack(spacing: 8) {
                        if let insiders = ownership.insidersPctHeld {
                            ownershipTile("Insiders", StreetAnalysisFormatters.formatPctHeld(insiders))
                        }
                        if let institutions = ownership.institutionsPctHeld {
                            ownershipTile("Institutions", StreetAnalysisFormatters.formatPctHeld(institutions))
                        }
                    }
                }

                if let holders = ownership.topInstitutional, !holders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TOP INSTITUTIONAL HOLDERS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .tracking(0.4)

                        ForEach(holders) { holder in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(holder.holder)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.label)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(holderDetail(holder))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                    }
                }

                if let transactions = ownership.recentInsiderTransactions, !transactions.isEmpty {
                    insiderTransactionsBlock(transactions)
                }

                Text(StreetAnalysisFormatters.attribution(dataAsOf: dataAsOf))
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
            .appPanel(subtle: true)
        } else {
            Text("Ownership and insider activity aren't available for this symbol.")
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appPanel(subtle: true)
        }
    }

    private func ownershipTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(AppTypography.cardTitle.monospacedDigit())
                .foregroundStyle(AppColors.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.secondaryFill.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.separator, lineWidth: 1)
        }
    }

    private func holderDetail(_ holder: InstitutionalHolder) -> String {
        var parts: [String] = []
        if let pct = holder.pctHeld {
            parts.append(StreetAnalysisFormatters.formatPctHeld(pct))
        }
        if let shares = holder.shares {
            parts.append(StreetAnalysisFormatters.formatShares(shares))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func insiderTransactionsBlock(_ transactions: [InsiderTransactionRow]) -> some View {
        let visible = showAllInsiderTx ? transactions : Array(transactions.prefix(insiderPreviewLimit))
        let hasMore = transactions.count > insiderPreviewLimit

        VStack(alignment: .leading, spacing: 8) {
            Text("INSIDER TRANSACTIONS (\(transactions.count))")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .tracking(0.4)

            ForEach(visible) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(StreetAnalysisFormatters.formatActionDate(row.date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(AppColors.tertiaryLabel)
                        Text(row.insider)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 6) {
                        if let transaction = row.transaction, !transaction.isEmpty {
                            Text(transaction)
                        }
                        if let shares = row.shares {
                            Text(StreetAnalysisFormatters.formatShares(shares))
                        }
                        if let value = row.value {
                            Text(StreetAnalysisFormatters.formatCompactUSD(value))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
                }
                .padding(.vertical, 2)
            }

            if hasMore {
                Button(showAllInsiderTx ? "Show fewer" : "View all \(transactions.count) transactions") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllInsiderTx.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
            }
        }
    }
}
