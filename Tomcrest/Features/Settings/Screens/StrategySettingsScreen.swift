import SwiftUI

struct StrategySettingsScreen: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AuthSession.self) private var auth

    var body: some View {
        SettingsScreenShell(title: "Strategy") {
            if viewModel.strategyJourney != nil || viewModel.isLoadingStrategy {
                StrategySettingsPanel(
                    title: "Setup checklist",
                    footnote: journeyFootnote
                ) {
                    StrategyJourneySection(viewModel: viewModel)
                }
            }

            StrategySettingsEditor(viewModel: viewModel)
        }
    }

    private var journeyFootnote: String? {
        guard let journey = viewModel.strategyJourney else { return nil }
        if journey.completedAt != nil { return "Complete" }
        return "\(Int(journey.completionPct.rounded()))% done"
    }
}

struct StrategySettingsEditor: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AuthSession.self) private var auth
    @State private var showScreener = false

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            if viewModel.isLoadingStrategy, viewModel.strategyCatalog.isEmpty {
                loadingState
            } else if let strategyError = viewModel.strategyError, viewModel.strategyCatalog.isEmpty {
                AppInlineBanner(message: strategyError, tone: .error)
            } else {
                strategyForm
            }
        }
    }

    @ViewBuilder
    private var strategyForm: some View {
        if let hero = selectedStrategyItem {
            strategyHero(hero)
        }

        if !viewModel.strategyCatalog.isEmpty {
            StrategySettingsPanel(title: "Playbook", footnote: "Your primary investing style") {
                VStack(spacing: 10) {
                    ForEach(viewModel.strategyCatalog) { item in
                        StrategyPickerCard(
                            item: item,
                            isSelected: viewModel.selectedStrategyId == item.id
                        ) {
                            viewModel.selectStrategy(item.id)
                        }
                    }
                }
            }
        }

        if viewModel.selectedStrategyId != nil {
            StrategySettingsPanel(title: "Profile") {
                VStack(alignment: .leading, spacing: 18) {
                    StrategyOptionChips(
                        label: "Risk tolerance",
                        footnote: viewModel.deltaBandDescription,
                        selection: Binding(
                            get: { viewModel.selectedRiskTolerance },
                            set: { viewModel.updateRiskTolerance($0) }
                        ),
                        options: StrategyFormSupport.riskOptions
                    )

                    if viewModel.isWheelLikeStrategy {
                        StrategyOptionChips(
                            label: "Income vs growth",
                            selection: Binding(
                                get: { viewModel.incomeVsGrowth },
                                set: { viewModel.updateIncomeVsGrowth($0) }
                            ),
                            options: StrategyFormSupport.incomeVsGrowthOptions
                        )

                        StrategyOptionChips(
                            label: "Options experience",
                            selection: Binding(
                                get: { viewModel.optionsExperience },
                                set: { viewModel.updateOptionsExperience($0) }
                            ),
                            options: StrategyFormSupport.optionsExperienceOptions
                        )
                    }
                }
            }

            strategySetupSection

            if let strategyId = viewModel.selectedStrategyId {
                Button {
                    showScreener = true
                } label: {
                    SettingsNavigationRow(
                        icon: "line.3.horizontal.decrease.circle",
                        title: "Stock screener",
                        subtitle: "Filter tickers for this playbook"
                    )
                }
                .buttonStyle(.plain)
                .background(AppColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.panelBorder, lineWidth: 1)
                }
                .sheet(isPresented: $showScreener) {
                    StrategyStockScreenerSheet(strategyId: strategyId, auth: auth) { symbol in
                        await viewModel.addSymbolToWatchlist(symbol)
                    }
                }
            }
        }

        if let strategyError = viewModel.strategyError, !viewModel.strategyCatalog.isEmpty {
            AppInlineBanner(message: strategyError, tone: .error)
        }

        if let saved = viewModel.strategySavedMessage {
            AppInlineBanner(message: saved, tone: .success)
        }

        BacktestRunButton(
            title: "Save strategy",
            loadingTitle: "Saving…",
            icon: "checkmark",
            isLoading: viewModel.isSavingStrategy,
            isDisabled: !viewModel.canSaveStrategy,
            action: {
                Task { await viewModel.saveStrategy() }
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var strategySetupSection: some View {
        if viewModel.isWheelLikeStrategy {
            StrategySettingsPanel(title: "Options parameters", footnote: "Defaults for wheel and income playbooks") {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        BacktestDecimalField(
                            label: "Delta min",
                            placeholder: "0.20",
                            value: $viewModel.targetDeltaMin,
                            fractionDigits: 2
                        )
                        BacktestDecimalField(
                            label: "Delta max",
                            placeholder: "0.30",
                            value: $viewModel.targetDeltaMax,
                            fractionDigits: 2
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Days to expiration")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.secondaryLabel)
                        BacktestChipRow(
                            options: [(7, "7d"), (14, "14d"), (21, "21d"), (30, "30d"), (45, "45d")],
                            selection: $viewModel.preferredDteDays
                        )
                    }

                    StrategySliderField(
                        label: "Max single-name weight",
                        footnote: "Cap concentration in one ticker",
                        value: $viewModel.maxSingleNamePct,
                        range: 5 ... 30,
                        step: 1
                    ) { "\(Int($0))%" }
                }
            }
        } else if viewModel.selectedStrategyId == "etf-core" {
            StrategySettingsPanel(title: "ETF allocation") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stock ETF")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.secondaryLabel)
                        AppFormField(placeholder: "VTI", text: $viewModel.etfPrimary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bond ETF")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.secondaryLabel)
                        AppFormField(placeholder: "BND", text: $viewModel.etfBond)
                    }

                    StrategySliderField(
                        label: "Stock allocation",
                        value: $viewModel.etfStockPct,
                        range: 50 ... 90,
                        step: 5
                    ) { "\(Int($0))%" }

                    StrategySliderField(
                        label: "Rebalance threshold",
                        footnote: "Drift before suggesting a rebalance",
                        value: $viewModel.rebalanceThresholdPct,
                        range: 3 ... 15,
                        step: 1
                    ) { "\(Int($0))%" }
                }
            }
        } else {
            StrategySettingsPanel(
                title: "Watchlist",
                footnote: "Symbols that power your playbook and research shortcuts"
            ) {
                TextField(
                    "AAPL, MSFT, SCHD",
                    text: Binding(
                        get: { viewModel.watchlistSymbolsText },
                        set: { viewModel.updateWatchlistSymbols($0) }
                    ),
                    axis: .vertical
                )
                .lineLimit(2 ... 5)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body)
                .foregroundStyle(AppColors.label)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.separator, lineWidth: 1)
                }
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).tint(AppColors.accent)
            Text("Loading strategy…")
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appHeroPanel()
    }

    private var selectedStrategyItem: StrategyCatalogItem? {
        guard let id = viewModel.selectedStrategyId else { return nil }
        return viewModel.strategyCatalog.first(where: { $0.id == id })
    }

    private func strategyHero(_ item: StrategyCatalogItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: StrategyPlaybookHelpers.strategyIconName(for: item.id))
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .frame(width: 48, height: 48)
                .background(AppColors.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.label)

                Text(item.subtitle)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(2)

                if viewModel.isWheelLikeStrategy {
                    Text(viewModel.deltaBandDescription)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.accentHighlight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accentMuted.opacity(0.45))
                        .clipShape(Capsule())
                }
            }

            Spacer(minLength: 0)
        }
        .appHeroPanel()
    }
}

// MARK: - Layout primitives

private struct StrategySettingsPanel<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .tracking(0.4)
                if let footnote {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(2)
                }
            }

            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.secondaryBackground.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.panelBorder, lineWidth: 1)
                }
        }
    }
}

private struct StrategyPickerCard: View {
    let item: StrategyCatalogItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: StrategyPlaybookHelpers.strategyIconName(for: item.id))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? AppColors.accentHighlight : AppColors.secondaryLabel)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? AppColors.accentMuted : AppColors.insetSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        .multilineTextAlignment(.leading)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? AppColors.accentHighlight : AppColors.tertiaryLabel)
            }
            .padding(12)
            .background(isSelected ? AppColors.accentMuted.opacity(0.28) : AppColors.insetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? AppColors.accentHighlight.opacity(0.4) : AppColors.separator,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct StrategyOptionChips: View {
    let label: String
    var footnote: String?
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.secondaryLabel)
                if let footnote {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection == option
                    Button {
                        selection = option
                    } label: {
                        Text(option.capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? AppColors.accentHighlight : AppColors.secondaryLabel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? AppColors.accentMuted : AppColors.insetSurface)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(
                                        isSelected ? AppColors.accentHighlight.opacity(0.35) : AppColors.separator,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct StrategySliderField: View {
    let label: String
    var footnote: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.label)
                    if let footnote {
                        Text(footnote)
                            .font(.caption2)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }
                Spacer(minLength: 8)
                Text(format(value))
                    .font(AppTypography.monoCaptionSemibold)
                    .foregroundStyle(AppColors.accentHighlight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accentMuted.opacity(0.45))
                    .clipShape(Capsule())
            }

            Slider(value: $value, in: range, step: step)
                .tint(AppColors.accent)
        }
    }
}
