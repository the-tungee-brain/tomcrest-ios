import SwiftUI

struct PositionGuidancePanelView: View {
    let symbol: String
    let accessToken: String?
    let guidance: SymbolPositionGuidance?
    let isLoading: Bool
    let errorMessage: String?
    var onRetry: (() -> Void)?

    var body: some View {
        Group {
            if accessToken == nil {
                AppScreenSection(title: "Position guidance") {
                    AppInlineBanner(message: "Sign in to load position guidance.", tone: .neutral)
                }
            } else if isLoading, guidance == nil {
                AppScreenSection(title: "Position guidance") {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let errorMessage, guidance == nil {
                AppScreenSection(title: "Position guidance") {
                    VStack(alignment: .leading, spacing: 10) {
                        AppInlineBanner(message: errorMessage, tone: .error)
                        if let onRetry {
                            Button("Try again", action: onRetry)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            } else if let guidance {
                guidanceContent(guidance)
            } else {
                AppScreenSection(title: "Position guidance") {
                    VStack(alignment: .leading, spacing: 10) {
                        AppInlineBanner(message: "Position guidance unavailable.", tone: .neutral)
                        if let onRetry {
                            Button("Try again", action: onRetry)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func guidanceContent(_ guidance: SymbolPositionGuidance) -> some View {
        let driverMap = GuidancePresentation.buildDriverDisplay(positions: guidance.positions)

        AppScreenSection(title: "Position guidance") {
            VStack(alignment: .leading, spacing: 14) {
                if let thesis = guidance.thesis {
                    Text(GuidancePresentation.symbolThesisLine(
                        thesis: thesis,
                        positions: guidance.positions
                    ))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if guidance.hasPositions, !guidance.positions.isEmpty {
                    ForEach(guidance.positions) { item in
                        positionCard(
                            item,
                            drivers: driverMap[item.positionKey] ?? [],
                            copy: GuidancePresentation.positionCopy(
                                item: item,
                                drivers: driverMap[item.positionKey] ?? []
                            )
                        )
                    }
                } else {
                    Text("No open positions for this symbol.")
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
            .appPanel(subtle: true)
        }
    }

    private func positionCard(
        _ item: PositionGuidanceItem,
        drivers: [GuidancePresentation.DedupedDriver],
        copy: GuidancePresentation.PositionCopy
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kindLabel(item.positionKind))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)

            Text(GuidancePresentation.contractLine(item))
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryLabel)

            Text(verdictLabel(item.verdict))
                .font(.headline.weight(.bold))
                .foregroundStyle(verdictColor(item.verdict))

            if item.verdict != "HOLD" {
                Text(GuidancePresentation.urgencyLabel(item.urgency))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            if let pl = GuidancePresentation.profitLossText(item.openProfitLossPct) {
                Text(pl)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            if let main = copy.mainReason {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Main reason:")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text(main)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }

            if !copy.supportingPoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Also contributing:")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    ForEach(copy.supportingPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(point)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryLabel)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func kindLabel(_ kind: PositionKind) -> String {
        switch kind {
        case .equityLong: "Equity"
        case .longCall: "Long call"
        case .longPut: "Long put"
        case .shortCall: "Short call"
        case .shortPut: "Short put"
        }
    }

    private func verdictLabel(_ verdict: String) -> String {
        switch verdict {
        case "HOLD": "Hold"
        case "TRIM": "Trim"
        case "REVIEW_SELL": "Review sell"
        case "EXIT": "Exit"
        case "REVIEW_CLOSE": "Review close"
        case "CLOSE": "Close"
        case "ROLL": "Roll"
        case "REVIEW_ASSIGNMENT_RISK": "Review assignment risk"
        default: verdict.capitalized
        }
    }

    private func verdictColor(_ verdict: String) -> Color {
        switch verdict {
        case "HOLD": AppColors.success
        case "TRIM", "ROLL": AppColors.accentHighlight
        case "REVIEW_SELL", "REVIEW_CLOSE", "REVIEW_ASSIGNMENT_RISK": AppColors.warning
        case "EXIT", "CLOSE": AppColors.danger
        default: AppColors.label
        }
    }
}

struct PortfolioExitAttentionSection: View {
    let items: [PortfolioExitAttentionItem]
    let onSymbolTap: (String) -> Void

    var body: some View {
        if items.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Positions to review")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)

                ForEach(items) { item in
                    Button {
                        onSymbolTap(item.symbol)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.symbol)
                                    .font(.subheadline.weight(.semibold).monospaced())
                                    .foregroundStyle(AppColors.accent)
                                Spacer()
                                Text(verdictLabel(item.verdict))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(verdictColor(item.verdict))
                            }
                            Text(kindLabel(item.positionKind) + " · " + item.displayLabel)
                                .font(.caption2)
                                .foregroundStyle(AppColors.tertiaryLabel)
                            if item.verdict != "HOLD" {
                                Text(GuidancePresentation.urgencyLabel(item.urgency))
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                        .padding(12)
                        .background(AppColors.secondaryBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .appPanel(subtle: true)
        }
    }

    private func kindLabel(_ kind: PositionKind) -> String {
        switch kind {
        case .equityLong: "Equity"
        case .longCall: "Long call"
        case .longPut: "Long put"
        case .shortCall: "Short call"
        case .shortPut: "Short put"
        }
    }

    private func verdictLabel(_ verdict: String) -> String {
        switch verdict {
        case "HOLD": "Hold"
        case "TRIM": "Trim"
        case "REVIEW_SELL": "Review sell"
        case "EXIT": "Exit"
        case "REVIEW_CLOSE": "Review close"
        case "CLOSE": "Close"
        case "ROLL": "Roll"
        case "REVIEW_ASSIGNMENT_RISK": "Review assignment"
        default: verdict
        }
    }

    private func verdictColor(_ verdict: String) -> Color {
        switch verdict {
        case "HOLD": AppColors.success
        case "TRIM", "ROLL": AppColors.accentHighlight
        case "REVIEW_SELL", "REVIEW_CLOSE", "REVIEW_ASSIGNMENT_RISK": AppColors.warning
        case "EXIT", "CLOSE": AppColors.danger
        default: AppColors.label
        }
    }
}
