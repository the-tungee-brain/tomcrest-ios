import SwiftUI

struct SymbolAnalysisSection: View {
    let symbol: String
    let isLoading: Bool
    let statusText: String?
    let errorMessage: String?
    let analysis: StructuredAnalysis?
    let precomputed: SymbolAnalysisPrecomputed?
    let onAnalyze: () -> Void
    var onAskFollowUp: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .frame(width: 32, height: 32)
                    .background(AppColors.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Position analysis")
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text("Structured read on your \(symbol) holdings and open options")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                }

                Spacer(minLength: 0)
            }

            if StructuredAnalysisSupport.hasComparePaths(precomputed),
               let precomputed {
                ComparePathsCard(
                    outcomes: precomputed.heldOptionOutcomes,
                    recommendedPath: StructuredAnalysisSupport.inferRecommendedComparePath(
                        from: analysis?.recommendedAction?.title
                    )
                )
            }

            if let analysis {
                symbolAnalysisContent(analysis)
            } else if isLoading {
                HStack(spacing: 10) {
                    ProgressView().tint(AppColors.accent)
                    Text(statusText ?? "Reviewing your position…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            } else {
                Button(action: onAnalyze) {
                    Text("Analyze position")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
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
        .appPanel()
    }

    @ViewBuilder
    private func symbolAnalysisContent(_ analysis: StructuredAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(analysis.summary)
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.label)
                .lineSpacing(4)

            if let action = analysis.recommendedAction {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended next step")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)
                    Text(action.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text(action.reason)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(2)

                    if let onAskFollowUp {
                        Button("Ask follow-up in chat") {
                            onAskFollowUp(
                                "Follow up on my \(symbol) position analysis: \(action.title). \(action.reason)"
                            )
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.accentMuted.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ForEach(analysis.sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    if let body = section.body, !body.isEmpty {
                        Text(body)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }
                    if let bullets = section.bullets {
                        ForEach(bullets, id: \.self) { bullet in
                            Text("• \(bullet)")
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                    }
                }
            }
        }
    }
}

struct ComparePathsCard: View {
    let outcomes: [HeldOptionOutcomes]
    let recommendedPath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compare paths")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            Text("Side-by-side roll, close, and hold outcomes for open options.")
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)

            ForEach(outcomes) { outcome in
                VStack(alignment: .leading, spacing: 8) {
                    Text(legLabel(outcome.currentLeg))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)

                    ForEach(sortedPaths(outcome.comparePaths), id: \.path) { path in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(path.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(
                                        path.path == recommendedPath
                                            ? AppColors.accentHighlight
                                            : AppColors.label
                                    )
                                if path.path == recommendedPath {
                                    Text("Suggested")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(AppColors.accentHighlight)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.accentMuted.opacity(0.5))
                                        .clipShape(Capsule())
                                }
                            }
                            ForEach(path.lines, id: \.self) { line in
                                Text("• \(line)")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.secondaryBackground.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .padding(12)
        .background(AppColors.secondaryBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func legLabel(_ leg: OptionLegOutcome) -> String {
        let side = (leg.side ?? leg.putCall ?? "option").uppercased()
        return "\(side) \(CurrencyFormatter.usd(leg.strike)) · exp \(leg.expiration.prefix(10))"
    }

    private func sortedPaths(_ paths: [ComparePathOption]) -> [ComparePathOption] {
        let order = ["roll", "close", "hold"]
        return paths.sorted {
            (order.firstIndex(of: $0.path) ?? 99) < (order.firstIndex(of: $1.path) ?? 99)
        }
    }
}

struct OptionsTabPrompt: View {
    let symbol: String
    var onOpenOptions: () -> Void

    var body: some View {
        Button(action: onOpenOptions) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundStyle(AppColors.accentHighlight)
                    .frame(width: 36, height: 36)
                    .background(AppColors.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Options intelligence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text("Strike scorecard, roll suggestions, and chain preview on the Options tab.")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
            .padding(12)
            .background(AppColors.accentMuted.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
