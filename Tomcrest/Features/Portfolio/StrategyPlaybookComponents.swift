import SwiftUI

// MARK: - Strategy playbook (web StrategyPlaybookPanel)

struct StrategyPlaybookCard: View {
    let strategyId: String
    let catalogItem: StrategyCatalogItem?
    let recommendations: StrategyRecommendations?
    let isLoading: Bool
    var onEditPlaybook: () -> Void
    var onRunAction: (StrategyNextAction) -> Void
    var onConnectSchwab: () -> Void
    var onOpenSymbol: (String) -> Void
    var isConnectingSchwab = false
    var wheelSymbols: [String] = []

    private var strategyTitle: String {
        StrategyPlaybookHelpers.formatPlaybookTitle(strategyId: strategyId, catalogItem: catalogItem)
    }

    private var strategySubtitle: String {
        catalogItem?.subtitle ?? "Your guided investing playbook"
    }

    private var symbolStatuses: [StrategySymbolStatus] {
        recommendations?.symbolStatuses ?? []
    }

    private var topAction: StrategyNextAction? {
        StrategyPlaybookHelpers.primaryPlaybookAction(from: recommendations)
    }

    var body: some View {
        Group {
            if isLoading, recommendations == nil {
                loadingPlaceholder
            } else {
                playbookContent
            }
        }
        .appPanel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Strategy playbook")
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.secondaryFill)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColors.secondaryFill)
                        .frame(width: 100, height: 10)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColors.secondaryFill)
                        .frame(width: 140, height: 12)
                }
                Spacer(minLength: 0)
            }
            Text("Loading playbook…")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .redacted(reason: .placeholder)
    }

    private var playbookContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let topAction {
                nextUpCallout(topAction)
            }

            if symbolStatuses.isEmpty {
                emptySymbolsState
            } else {
                symbolSection
            }

            if let flow = StrategyFlows.flow(for: strategyId) {
                strategyFlowSection(flow)
            }

            if strategyId == "wheel", !playbookSymbols.isEmpty {
                wheelBacktestSection
            }
        }
    }

    private var playbookSymbols: [String] {
        if !wheelSymbols.isEmpty {
            return wheelSymbols
        }
        return symbolStatuses.map(\.symbol)
    }

    private var wheelBacktestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Historical backtest", systemImage: "chart.xyaxis.line")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            Text("Run a full chart and trade log on the symbol's research Backtest tab.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(Set(playbookSymbols)).sorted(), id: \.self) { symbol in
                    Button {
                        onOpenSymbol(symbol)
                    } label: {
                        Text(symbol)
                            .font(AppTypography.monoCaption2Semibold)
                            .foregroundStyle(AppColors.accentHighlight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(AppColors.accentMuted.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(AppColors.accentMuted.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func strategyFlowSection(_ flow: StrategyFlowDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("How it works")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                if flow.repeats {
                    Label("Repeating cycle", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }

            StrategySerpentineFlowDiagram(flow: flow)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: StrategyPlaybookHelpers.strategyIconName(for: strategyId))
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .frame(width: 32, height: 32)
                .background(AppColors.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Strategy playbook")
                    .font(AppTypography.bodySecondary.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(strategyTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(strategySubtitle)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Spacer(minLength: 0)

            Button(action: onEditPlaybook) {
                Label("Edit", systemImage: "slider.horizontal.3")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppColors.insetSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppColors.separator, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func nextUpCallout(_ action: StrategyNextAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next up")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .textCase(.uppercase)

            Text(action.title)
                .font(AppTypography.bodySecondary.weight(.semibold))
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)

            Text(action.reason)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            PlaybookActionButtons(
                action: action,
                onRunAction: onRunAction,
                onConnectSchwab: onConnectSchwab,
                onOpenSymbol: onOpenSymbol,
                isConnectingSchwab: isConnectingSchwab
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accentMuted.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
        }
    }

    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your symbols")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            VStack(spacing: 10) {
                ForEach(symbolStatuses) { status in
                    PlaybookSymbolCard(
                        strategyId: strategyId,
                        status: status,
                        onRunAction: onRunAction,
                        onConnectSchwab: onConnectSchwab,
                        onOpenSymbol: onOpenSymbol,
                        isConnectingSchwab: isConnectingSchwab
                    )
                }
            }
        }
    }

    private var emptySymbolsState: some View {
        VStack(spacing: 8) {
            Text("No symbols on your playbook yet")
                .font(AppTypography.bodySecondary.weight(.semibold))
                .foregroundStyle(AppColors.label)
            Text("Add tickers in settings or use the strategy screener to build your list.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
            Button("Add symbols", action: onEditPlaybook)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.accentMuted.opacity(0.5))
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(AppColors.secondaryBackground.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppColors.separator.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }
}

// MARK: - Symbol card

private struct PlaybookSymbolCard: View {
    let strategyId: String
    let status: StrategySymbolStatus
    var onRunAction: (StrategyNextAction) -> Void
    var onConnectSchwab: () -> Void
    var onOpenSymbol: (String) -> Void
    var isConnectingSchwab = false

    private var holdBadge: String {
        StrategyPlaybookHelpers.playbookHoldBadge(status)
    }

    private var showWheelPhase: Bool {
        StrategyPlaybookHelpers.isWheelLikeStrategy(strategyId) && status.wheelPhase != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    onOpenSymbol(status.symbol)
                } label: {
                    Text(status.symbol)
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text(holdBadge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(holdBadgeForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(holdBadgeBackground)
                    .clipShape(Capsule())
            }

            Text(status.statusLabel)
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)

            if showWheelPhase, let phase = status.wheelPhase {
                StrategyWheelPhaseStepper(strategyId: strategyId, phase: phase)
            }

            if let weight = status.portfolioWeightPct, status.held {
                Text("\(CurrencyFormatter.compactPercent(weight)) of portfolio")
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }

            if let nextAction = status.nextAction {
                Divider()
                    .overlay(AppColors.separator)

                VStack(alignment: .leading, spacing: 6) {
                    Text(StrategyPlaybookHelpers.actionTypeLabel(nextAction.type))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.secondaryBackground)
                        .clipShape(Capsule())

                    Text(nextAction.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(nextAction.reason)
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    PlaybookActionButtons(
                        action: nextAction,
                        onRunAction: onRunAction,
                        onConnectSchwab: onConnectSchwab,
                        onOpenSymbol: onOpenSymbol,
                        isConnectingSchwab: isConnectingSchwab,
                        compact: true
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceElevated.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private var holdBadgeForeground: Color {
        switch holdBadge {
        case "Held": AppColors.accentHighlight
        case "Partial": AppColors.label
        default: AppColors.secondaryLabel
        }
    }

    private var holdBadgeBackground: Color {
        switch holdBadge {
        case "Held": AppColors.accentMuted.opacity(0.45)
        case "Partial": AppColors.secondaryFill
        default: AppColors.secondaryBackground
        }
    }
}

// MARK: - Action buttons

private struct PlaybookActionButtons: View {
    let action: StrategyNextAction
    var onRunAction: (StrategyNextAction) -> Void
    var onConnectSchwab: () -> Void
    var onOpenSymbol: (String) -> Void
    var isConnectingSchwab = false
    var compact = false

    private var symbol: String? {
        action.symbol?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: compact ? 120 : 140), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            if StrategyPlaybookHelpers.playbookActionAskable(action) {
                Button {
                    onRunAction(action)
                } label: {
                    Text(askLabel)
                        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                        .padding(.horizontal, compact ? 10 : 12)
                        .padding(.vertical, compact ? 6 : 8)
                        .background(AppColors.accentMuted.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if action.type == "connect" {
                Button(action: onConnectSchwab) {
                    Group {
                        if isConnectingSchwab {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Text("Connect Schwab")
                        }
                    }
                    .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                    .padding(.horizontal, compact ? 10 : 12)
                    .padding(.vertical, compact ? 6 : 8)
                    .background(AppColors.secondaryFill)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isConnectingSchwab)
            } else if let symbol, !symbol.isEmpty, action.type != "education" {
                Button {
                    onOpenSymbol(symbol)
                } label: {
                    Text(secondaryLabel)
                        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                        .padding(.horizontal, compact ? 10 : 12)
                        .padding(.vertical, compact ? 6 : 8)
                        .background(AppColors.secondaryBackground)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppColors.separator, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var askLabel: String {
        if let symbol, !symbol.isEmpty {
            return "Ask AI about \(symbol)"
        }
        return "Ask AI"
    }

    private var secondaryLabel: String {
        switch action.type {
        case "options": return "View options"
        case "monitor": return "View position"
        case "research", "buy": return "Open research"
        default: return "Open \(symbol ?? "symbol")"
        }
    }
}

// MARK: - Strategy flow diagram (legacy vertical fallback removed — see StrategyFlowComponents)

