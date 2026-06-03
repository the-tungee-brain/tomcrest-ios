import SwiftUI

struct PortfolioAnalysisSection: View {
    let isLoading: Bool
    let statusText: String?
    let errorMessage: String?
    let analysis: StructuredAnalysis?
    let precomputed: PortfolioAnalysisPrecomputed?
    let onAnalyze: () -> Void
    var progressiveDisclosure = false

    @State private var disclosureExpanded = false

    private var hasAnalysis: Bool { analysis != nil }

    private var showContent: Bool {
        guard progressiveDisclosure else { return true }
        if isLoading { return true }
        return disclosureExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .frame(width: 32, height: 32)
                    .background(AppColors.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Portfolio analysis")
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text("Structured diversification review with cash map and action plan")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                }

                Spacer(minLength: 0)

                if progressiveDisclosure, hasAnalysis, !isLoading {
                    Button(disclosureExpanded ? "Hide" : "Expand") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            disclosureExpanded.toggle()
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .buttonStyle(.plain)
                }
            }

            if showContent {
                analysisBody
            } else if progressiveDisclosure, !hasAnalysis {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        disclosureExpanded = true
                    }
                    onAnalyze()
                } label: {
                    Text("Go deeper")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                }
                .buttonStyle(.plain)
            }
        }
        .appPanel()
        .onChange(of: hasAnalysis) { _, available in
            if available {
                withAnimation(.easeInOut(duration: 0.2)) {
                    disclosureExpanded = true
                }
            }
        }
    }

    @ViewBuilder
    private var analysisBody: some View {
        if let precomputed, !precomputed.holdings.isEmpty {
            PortfolioAllocationCard(precomputed: precomputed)
        }

        if let analysis {
            analysisContent(analysis)
        } else if isLoading {
            HStack(spacing: 10) {
                ProgressView().tint(AppColors.accent)
                Text(statusText ?? "Reviewing your portfolio…")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        } else {
            Button("Run analysis", action: onAnalyze)
                .buttonStyle(AppCompactButtonStyle())
        }

        if let errorMessage, !errorMessage.isEmpty {
            AppInlineBanner(message: errorMessage, tone: .error)
        }

        if analysis != nil, !isLoading {
            Button(action: onAnalyze) {
                Text("Re-analyze")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func analysisContent(_ analysis: StructuredAnalysis) -> some View {
        StructuredAnalysisView(analysis: analysis)
    }
}

struct PortfolioAllocationCard: View {
    let precomputed: PortfolioAnalysisPrecomputed

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Allocation map")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                allocationChip("Deployable", CurrencyFormatter.usd(precomputed.concentration.deployableCash, fractionDigits: 0), accent: true)
                allocationChip("Top 1", CurrencyFormatter.compactPercent(precomputed.concentration.top1Pct))
                allocationChip("Top 3", CurrencyFormatter.compactPercent(precomputed.concentration.top3Pct))
                allocationChip("Cash", CurrencyFormatter.compactPercent(precomputed.concentration.cashPct))
            }

            if !precomputed.cashMap.steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cash map")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)
                    ForEach(precomputed.cashMap.steps) { step in
                        HStack {
                            Text(step.label)
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                            Spacer()
                            if let amount = step.amount {
                                Text(CurrencyFormatter.usd(amount, fractionDigits: 0))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(step.isSubtraction == true ? AppColors.error : AppColors.label)
                            }
                        }
                    }
                }
            }

            if !precomputed.holdings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Holdings review")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)
                    ForEach(precomputed.holdings.prefix(8)) { holding in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(holding.symbol)
                                    .font(.caption.weight(.semibold).monospaced())
                                Spacer()
                                Text(CurrencyFormatter.compactPercent(holding.weightPct))
                                    .font(.caption.monospacedDigit())
                            }
                            Text(holding.status)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(statusColor(holding.status))
                            Text(holding.actionSummary)
                                .font(.caption2)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                        .padding(10)
                        .background(AppColors.surfaceElevated.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            if !precomputed.trimPlan.isEmpty || !precomputed.deployPlan.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    if !precomputed.trimPlan.isEmpty {
                        planColumn(title: "Trim plan", items: precomputed.trimPlan.map {
                            "\($0.symbol) · \(CurrencyFormatter.usd($0.trimDollars, fractionDigits: 0))"
                        })
                    }
                    if !precomputed.deployPlan.isEmpty {
                        planColumn(title: "Deploy plan", items: precomputed.deployPlan.map {
                            "\($0.symbol) · \(CurrencyFormatter.usd($0.deployDollars, fractionDigits: 0))"
                        })
                    }
                }
            }
        }
        .padding(12)
        .background(AppColors.secondaryBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func allocationChip(_ label: String, _ value: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(accent ? AppColors.accentHighlight : AppColors.label)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.insetSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func planColumn(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusColor(_ status: String) -> Color {
        let lower = status.lowercased()
        if lower.contains("too large") || lower.contains("very large") { return AppColors.error }
        if lower.contains("large") || lower.contains("above") { return AppColors.warning }
        if lower.contains("below") || lower.contains("small") { return AppColors.success }
        return AppColors.secondaryLabel
    }
}
