import SwiftUI

struct StrategySettingsScreen: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AuthSession.self) private var auth

    var body: some View {
        SettingsScreenShell(title: "Strategy") {
            StrategySettingsEditor(viewModel: viewModel)

            if viewModel.strategyJourney != nil || viewModel.isLoadingStrategy {
                AppScreenSection(
                    title: "Setup checklist",
                    footnote: journeyFootnote
                ) {
                    StrategyJourneySection(viewModel: viewModel)
                }
            }
        }
    }

    private var journeyFootnote: String? {
        guard let journey = viewModel.strategyJourney else { return nil }
        if journey.completedAt != nil { return "Complete" }
        return "\(Int(journey.completionPct.rounded()))% done"
    }
}

/// Full strategy editor — pushed screen (no nested disclosures).
struct StrategySettingsEditor: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AuthSession.self) private var auth
    @State private var showScreener = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingStrategy, viewModel.strategyCatalog.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(AppColors.accent)
                    Text("Loading strategy…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appPanel(subtle: true)
            } else if let strategyError = viewModel.strategyError, viewModel.strategyCatalog.isEmpty {
                AppInlineBanner(message: strategyError, tone: .error)
            } else {
                strategyForm
            }
        }
    }

    @ViewBuilder
    private var strategyForm: some View {
        if !viewModel.strategyCatalog.isEmpty {
            AppScreenSection(title: "Primary strategy") {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.strategyCatalog) { item in
                                AppChip(
                                    title: item.title,
                                    isSelected: viewModel.selectedStrategyId == item.id
                                ) {
                                    viewModel.selectStrategy(item.id)
                                }
                            }
                        }
                    }

                    if let subtitle = viewModel.strategyCatalog.first(where: {
                        $0.id == viewModel.selectedStrategyId
                    })?.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }

                    if let strategyId = viewModel.selectedStrategyId {
                        Button {
                            showScreener = true
                        } label: {
                            Label("Open stock screener", systemImage: "line.3.horizontal.decrease.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.accentHighlight)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showScreener) {
                            StrategyStockScreenerSheet(strategyId: strategyId, auth: auth) { symbol in
                                await viewModel.addSymbolToWatchlist(symbol)
                            }
                        }
                    }
                }
                .appPanel(subtle: true)
            }
        }

        AppScreenSection(title: "Preferences") {
            strategyPreferences
                .appPanel(subtle: true)
        }

        if let strategyError = viewModel.strategyError, !viewModel.strategyCatalog.isEmpty {
            AppInlineBanner(message: strategyError, tone: .error)
        }

        if let saved = viewModel.strategySavedMessage {
            AppInlineBanner(message: saved, tone: .success)
        }

        Button(viewModel.isSavingStrategy ? "Saving…" : "Save strategy") {
            Task { await viewModel.saveStrategy() }
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .disabled(!viewModel.canSaveStrategy || viewModel.isSavingStrategy)
    }

    @ViewBuilder
    private var strategyPreferences: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                SettingsFieldLabel(title: "Risk tolerance")
                Picker("Risk tolerance", selection: Binding(
                    get: { viewModel.selectedRiskTolerance },
                    set: { viewModel.updateRiskTolerance($0) }
                )) {
                    ForEach(StrategyFormSupport.riskOptions, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                Text(viewModel.deltaBandDescription)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            if viewModel.isWheelLikeStrategy {
                wheelPreferences
            }

            if viewModel.selectedStrategyId == "etf-core" {
                etfCorePreferences
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsFieldLabel(title: "Watchlist symbols")
                    AppFormField(
                        placeholder: "AAPL, MSFT, SCHD",
                        text: Binding(
                            get: { viewModel.watchlistSymbolsText },
                            set: { viewModel.updateWatchlistSymbols($0) }
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var wheelPreferences: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                SettingsFieldLabel(title: "Options experience")
                Picker("Options experience", selection: Binding(
                    get: { viewModel.optionsExperience },
                    set: { viewModel.updateOptionsExperience($0) }
                )) {
                    ForEach(StrategyFormSupport.optionsExperienceOptions, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsFieldLabel(title: "Income vs growth")
                Picker("Income vs growth", selection: Binding(
                    get: { viewModel.incomeVsGrowth },
                    set: { viewModel.updateIncomeVsGrowth($0) }
                )) {
                    ForEach(StrategyFormSupport.incomeVsGrowthOptions, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsFieldLabel(title: "Delta band")
                HStack {
                    Text("Min").font(.caption2)
                    TextField("Min", value: $viewModel.targetDeltaMin, format: .number)
                        .textFieldStyle(.roundedBorder)
                    Text("Max").font(.caption2)
                    TextField("Max", value: $viewModel.targetDeltaMax, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
                Stepper("DTE \(viewModel.preferredDteDays)", value: $viewModel.preferredDteDays, in: 5 ... 45)
                    .font(.caption)
                HStack {
                    Text("Max single name %").font(.caption2)
                    Slider(value: $viewModel.maxSingleNamePct, in: 5 ... 30, step: 1)
                    Text("\(Int(viewModel.maxSingleNamePct))%")
                        .font(.caption.monospacedDigit())
                }
            }
        }
    }

    @ViewBuilder
    private var etfCorePreferences: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsFieldLabel(title: "Stock ETF")
            AppFormField(placeholder: "VTI", text: $viewModel.etfPrimary)
            SettingsFieldLabel(title: "Bond ETF")
            AppFormField(placeholder: "BND", text: $viewModel.etfBond)
            SettingsFieldLabel(title: "Stock allocation")
            HStack {
                Slider(value: $viewModel.etfStockPct, in: 50 ... 90, step: 5)
                Text("\(Int(viewModel.etfStockPct))%")
                    .font(.caption.monospacedDigit())
            }
            SettingsFieldLabel(title: "Rebalance threshold")
            HStack {
                Slider(value: $viewModel.rebalanceThresholdPct, in: 3 ... 15, step: 1)
                Text("\(Int(viewModel.rebalanceThresholdPct))%")
                    .font(.caption.monospacedDigit())
            }
        }
    }
}
