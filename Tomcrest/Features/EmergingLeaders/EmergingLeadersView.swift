import SwiftUI

struct EmergingLeadersView: View {
    @Bindable var viewModel: EmergingLeadersViewModel
    var onOpenSymbol: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Emerging Leaders")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Token.textPrimary)
                Text("Setup quality before the move — complements Top Movers.")
                    .font(.subheadline)
                    .foregroundStyle(Token.textSecondary)
                if let metaLine = viewModel.metaLine {
                    Text(metaLine)
                        .font(.caption)
                        .foregroundStyle(Token.textTertiary)
                }
            }

            if viewModel.isLoading, viewModel.items.isEmpty {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                AppInlineBanner(message: errorMessage, tone: .error)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RANKED LIST")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Token.textTertiary)
                        .tracking(0.6)
                        .padding(.horizontal, 4)

                    AppGroupedList {
                        ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                            let symbol = item.symbol.uppercased()
                            EmergingLeaderRow(
                                item: item,
                                isExpanded: viewModel.expandedSymbol == symbol,
                                onToggle: { viewModel.toggleExpanded(symbol) },
                                onOpenSymbol: onOpenSymbol
                            )

                            if index < viewModel.items.count - 1 {
                                AppGroupedDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EmergingLeaderRow: View {
    let item: EmergingLeaderItem
    let isExpanded: Bool
    let onToggle: () -> Void
    var onOpenSymbol: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 10) {
                    symbolBlock
                    Spacer(minLength: 4)
                    trailingBlock
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Token.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, MoversRowMetrics.expandedHorizontalPadding)
                .padding(.vertical, 14)
                .frame(minHeight: Layout.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                EmergingLeaderExpandedContent(item: item, onOpenSymbol: onOpenSymbol)
            }
        }
        .background(isExpanded ? Token.surfaceFillSecondary.opacity(0.35) : Color.clear)
    }

    private var symbolBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(EmergingLeadersFormatting.rankLabel(item.rank))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(Token.textPrimary)
                .frame(minWidth: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.symbol.uppercased())
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Token.textPrimary)

                Text(item.setupStageLabel)
                    .font(.caption)
                    .foregroundStyle(Token.textSecondary)

                Text(
                    "Setup \(item.setupQualityScore)/100 · CV \(item.compressionVelocity)"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(Token.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trailingBlock: some View {
        VStack(alignment: .trailing, spacing: 6) {
            SetupStageBadge(stage: item.setupStage, label: item.setupStageLabel)
            Text("\(item.setupQualityScore)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(EmergingLeadersFormatting.setupScoreColor(item.setupQualityScore))
        }
    }
}

private struct EmergingLeaderExpandedContent: View {
    let item: EmergingLeaderItem
    var onOpenSymbol: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MoversRowMetrics.expandedSpacing) {
            MoversExpandedDivider()

            detailHeader

            VStack(alignment: .leading, spacing: 8) {
                MoversSectionTitle(title: "WHY IT RANKS")
                MoversCalloutBlock {
                    Text(item.whyItRanks)
                        .font(.subheadline)
                        .foregroundStyle(Token.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            MoversBulletListSection(
                title: "WHAT SUPPORTS THE SETUP",
                lines: item.positiveFactors,
                style: .checkmark
            )
            MoversBulletListSection(
                title: "WHAT IS STILL MISSING",
                lines: item.missingFactors,
                style: .warning
            )
            MoversBulletListSection(
                title: "NEXT CONFIRMATION TO WATCH",
                lines: item.nextConfirmation,
                style: .bullet
            )

            SymbolInvestigateActionBar(symbol: item.symbol) {
                onOpenSymbol(item.symbol.uppercased())
            }
        }
        .padding(.horizontal, MoversRowMetrics.expandedHorizontalPadding)
        .padding(.bottom, MoversRowMetrics.expandedBottomPadding)
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SetupStageBadge(stage: item.setupStage, label: item.setupStageLabel)
                Text(item.setupStageLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Token.textSecondary)
            }
            HStack(spacing: 10) {
                Text("Setup \(item.setupQualityScore)/100")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(
                        EmergingLeadersFormatting.setupScoreColor(item.setupQualityScore)
                    )
                Text(
                    "Compression \(item.compressionVelocityLabel) · \(item.compressionVelocity)/100"
                )
                .font(.caption)
                .foregroundStyle(Token.textSecondary)
            }
        }
    }
}
