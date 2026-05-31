import SwiftUI

// MARK: - Section chrome

struct SettingsFieldLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTypography.captionEmphasis)
            .foregroundStyle(AppColors.secondaryLabel)
    }
}

// MARK: - Brokerage

struct SchwabConnectionCard: View {
    let connected: Bool?
    let isLoading: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Schwab")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.label)
                Spacer(minLength: 12)
                if isLoading {
                    ProgressView().controlSize(.small).tint(AppColors.accent)
                }
                AppStatusPill(label: statusLabel, uppercase: false, tone: statusTone)
            }

            Text("Read-only access — view positions, no trades.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            // One primary action — pull to refresh on Settings replaces a third button.
            if connected == true {
                Button("Disconnect Schwab", role: .destructive, action: onDisconnect)
                    .buttonStyle(AppPrimaryButtonStyle(destructive: true))
                    .disabled(isLoading)
            } else {
                Button("Connect Schwab", action: onConnect)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(isLoading)
            }
        }
        .appPanel(subtle: true)
    }

    private var statusLabel: String {
        if isLoading, connected == nil { return "Checking…" }
        if let connected { return connected ? "Connected" : "Not connected" }
        return "Unknown"
    }

    private var statusTone: AppStatusPill.Tone {
        guard let connected else { return .neutral }
        return connected ? .success : .neutral
    }
}

// MARK: - Account identity

struct AccountIdentityRow: View {
    let email: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(email)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                    .textSelection(.enabled)
                Text("Signed in with Google")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }
}

// MARK: - Plan

struct AccountPlanCardView: View {
    let plan: AccountPlanResponse?
    let isLoading: Bool

    @State private var featuresExpanded = false

    private static let freeFeatures = [
        "Portfolio sync, morning brief, and strategy playbooks",
        "Portfolio and position analysis with AI-powered insights",
        "Research essentials: quotes, SEC filings, earnings history, news headlines",
        "Dividend history charts and allocation tools",
        "Assistant chat on free-tier AI models",
    ]

    private static let proFeatures = [
        "Most capable AI model for research synthesis and portfolio analysis",
        "AI earnings analysis (quarterly summaries & takeaways)",
        "AI news research (brief, sentiment, coverage analysis)",
        "Financial strength & fundamental AI on Research",
        "Big picture & business AI on Research Overview and Business",
        "Income snowball (DRIP projections & contributions)",
        "Wheel backtest with trade log and PDF export",
        "Advanced chat models (gpt-5.1, gpt-4o, gpt-5.4, o3, and more)",
    ]

    var body: some View {
        Group {
            if isLoading, plan == nil {
                loadingCard
            } else {
                planCard
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView().tint(AppColors.accent)
            Text("Loading plan…")
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }

    private var planCard: some View {
        let isPaid = plan?.isPaid ?? false
        let freeModel = plan?.freeModel ?? "gpt-4.1-mini"
        let backgroundModel = plan?.backgroundModel ?? "gpt-5.4"
        let features = isPaid ? Self.proFeatures : Self.freeFeatures

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isPaid ? "Pro" : "Free")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.label)
                    Text(planSummary(isPaid: isPaid, freeModel: freeModel))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                Spacer()
                PlanBadge(label: isPaid ? "Pro" : "Free", isPaid: isPaid)
            }

            AppDisclosureSection(
                title: "What's included",
                footnote: "\(features.count) features",
                isExpanded: $featuresExpanded
            ) {
                AppFeatureChecklist(
                    items: features,
                    footnote: isPaid ? proFootnote(backgroundModel) : freeFootnote(freeModel)
                )
            }

            if !isPaid, let url = proRequestURL {
                Link("Request Pro access", destination: url)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .appPanel(subtle: true)
    }

    private var proRequestURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Tomcrest Pro access")]
        return components.url
    }

    private func planSummary(isPaid: Bool, freeModel: String) -> String {
        if isPaid {
            return "Full access to every AI model and Pro research synthesis."
        }
        return "Portfolio analysis and chat on efficient models (default \(freeModel))."
    }

    private func freeFootnote(_ freeModel: String) -> String {
        "Research data is free; AI-generated earnings, news, business, and financial analysis require Pro."
    }

    private func proFootnote(_ backgroundModel: String) -> String {
        "Automated analysis uses \(backgroundModel). Billing is invite-only during beta."
    }
}

private struct PlanBadge: View {
    let label: String
    let isPaid: Bool

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isPaid ? AppColors.accentHighlight : AppColors.secondaryLabel)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isPaid ? AppColors.accent.opacity(0.15) : AppColors.secondaryFill)
            .clipShape(Capsule())
    }
}

// MARK: - Strategy (form + journey in one panel)

struct StrategySettingsCard: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var strategyExpanded: Bool
    @Environment(AuthSession.self) private var auth
    @State private var journeyExpanded = false
    @State private var preferencesExpanded = false
    @State private var showScreener = false

    init(viewModel: SettingsViewModel, strategyExpanded: Binding<Bool> = .constant(true)) {
        self.viewModel = viewModel
        _strategyExpanded = strategyExpanded
    }

    var body: some View {
        AppDisclosureSection(title: "Strategy editor", isExpanded: $strategyExpanded) {
            strategyCardBody
        }
    }

    private var strategyCardBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingStrategy, viewModel.strategyCatalog.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(AppColors.accent)
                    Text("Loading strategy…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            } else if let strategyError = viewModel.strategyError, viewModel.strategyCatalog.isEmpty {
                AppInlineBanner(message: strategyError, tone: .error)
            } else {
                strategyForm

                if viewModel.strategyJourney != nil || viewModel.isLoadingStrategy {
                    AppDisclosureSection(
                        title: "Setup checklist",
                        footnote: journeyFootnote,
                        isExpanded: $journeyExpanded
                    ) {
                        StrategyJourneySection(viewModel: viewModel)
                    }
                }
            }
        }
        .appPanel(subtle: true)
    }

    private var journeyFootnote: String? {
        guard let journey = viewModel.strategyJourney else { return nil }
        if journey.completedAt != nil { return "Complete" }
        return "\(Int(journey.completionPct.rounded()))% done"
    }

    @ViewBuilder
    private var strategyForm: some View {
        if !viewModel.strategyCatalog.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SettingsFieldLabel(title: "Primary strategy")

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
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
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
        }

        // Risk + watchlist are secondary — collapsed so strategy choice + Save stay primary.
        AppDisclosureSection(title: "Preferences", isExpanded: $preferencesExpanded) {
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
                            Text("Min")
                                .font(.caption2)
                            TextField("Min", value: $viewModel.targetDeltaMin, format: .number)
                                .textFieldStyle(.roundedBorder)
                            Text("Max")
                                .font(.caption2)
                            TextField("Max", value: $viewModel.targetDeltaMax, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Stepper("DTE \(viewModel.preferredDteDays)", value: $viewModel.preferredDteDays, in: 5 ... 45)
                                .font(.caption)
                        }
                        HStack {
                            Text("Max single name %")
                                .font(.caption2)
                            Slider(value: $viewModel.maxSingleNamePct, in: 5 ... 30, step: 1)
                            Text("\(Int(viewModel.maxSingleNamePct))%")
                                .font(.caption.monospacedDigit())
                        }
                    }
                }

                if viewModel.selectedStrategyId == "etf-core" {
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
}

// MARK: - Session & legal (merged panel)

struct AccountSessionPanel: View {
    let onSignOut: () -> Void

    var body: some View {
        AppGroupedList {
            settingsLinkRow("Security overview", url: AppConfig.securityURL)
            AppGroupedDivider()
            settingsLinkRow("Privacy Policy", url: AppConfig.privacyURL)
            AppGroupedDivider()
            settingsLinkRow("Terms of Service", url: AppConfig.termsURL)
            AppGroupedDivider()
            Button("Log out", role: .destructive, action: onSignOut)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.error)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: Layout.minTouchTarget)
        }
    }

    @ViewBuilder
    private func settingsLinkRow(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.label)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: Layout.minTouchTarget)
        }
    }
}

// MARK: - Delete account

struct DeleteAccountCard: View {
    let confirmDelete: Bool
    let isDeleting: Bool
    let error: String?
    let onBeginDelete: () -> Void
    let onConfirmDelete: () -> Void
    let onCancelDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                "Permanently removes your account, Schwab connection, chat history, " +
                    "strategy settings, and stored portfolio data."
            )
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.secondaryLabel)

            if let error {
                AppInlineBanner(message: error, tone: .error)
            }

            if confirmDelete {
                HStack(spacing: 10) {
                    Button(isDeleting ? "Deleting…" : "Delete permanently", role: .destructive) {
                        onConfirmDelete()
                    }
                    .buttonStyle(AppPrimaryButtonStyle(destructive: true))
                    .disabled(isDeleting)

                    Button("Cancel", action: onCancelDelete)
                        .buttonStyle(AppSecondaryButtonStyle())
                        .disabled(isDeleting)
                }
            } else {
                Button("Delete account", role: .destructive, action: onBeginDelete)
                    .buttonStyle(AppSecondaryButtonStyle(destructive: true))
            }
        }
    }
}

// MARK: - About

struct SettingsAboutCard: View {
    var body: some View {
        AppGroupedList {
            AppListRow {
                Text("Version")
                    .foregroundStyle(AppColors.secondaryLabel)
            } trailing: {
                Text("0.1.0")
                    .foregroundStyle(AppColors.label)
            }

            AppGroupedDivider()

            AppListRow {
                Text("Support")
                    .foregroundStyle(AppColors.secondaryLabel)
            } trailing: {
                Link(AppConfig.supportEmail, destination: supportURL)
                    .foregroundStyle(AppColors.accent)
            }
        }
        .font(.subheadline)
    }

    private var supportURL: URL {
        URL(string: "mailto:\(AppConfig.supportEmail)")!
    }
}

// Legacy aliases — use AppPrimaryButtonStyle / AppSecondaryButtonStyle in new code.
typealias SettingsPrimaryButtonStyle = AppPrimaryButtonStyle
typealias SettingsSecondaryButtonStyle = AppSecondaryButtonStyle
typealias SettingsTertiaryButtonStyle = AppTertiaryButtonStyle
