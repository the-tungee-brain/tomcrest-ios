import SwiftUI

// MARK: - Overview explore links

struct ResearchExploreLinks: View {
    let symbolItem: TickerSymbolItem
    let assetType: String?
    let availableTabs: [ResearchTab]
    var onOpenHub: (SymbolResearchDestination) -> Void

    private struct Row: Identifiable {
        let id: SymbolResearchDestination
        let destination: SymbolResearchDestination
        let title: String
        let subtitle: String
        let systemImage: String
    }

    private var rows: [Row] {
        SymbolResearchDestination.rows(assetType: assetType, availableTabs: availableTabs).map { destination in
            Row(
                id: destination,
                destination: destination,
                title: rowTitle(for: destination),
                subtitle: rowSubtitle(for: destination),
                systemImage: rowIcon(for: destination)
            )
        }
    }

    var body: some View {
        if !rows.isEmpty {
            AppScreenSection(title: "Go deeper") {
                AppGroupedList {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        Button {
                            onOpenHub(row.destination)
                        } label: {
                            ResearchHubLinkRow(
                                title: row.title,
                                subtitle: row.subtitle,
                                systemImage: row.systemImage
                            )
                        }
                        .buttonStyle(.plain)

                        if index < rows.count - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }

    private func rowTitle(for destination: SymbolResearchDestination) -> String {
        switch destination {
        case .metrics:
            return ResearchTab.metrics.metricsLabel(for: assetType)
        default:
            return destination.navigationTitle
        }
    }

    private func rowSubtitle(for destination: SymbolResearchDestination) -> String {
        switch destination {
        case .analysis:
            let normalized = assetType?.uppercased() ?? "STOCK"
            if normalized == "ETF" || normalized == "MUTUAL_FUND" || normalized == "INDEX" {
                return "5D alpha model and signals"
            }
            return "AI insights, 5D trend, and business context"
        case .metrics:
            return "Valuation, growth, and analyst views"
        case .news:
            return "Headlines and company releases"
        case .financials:
            return "Statements, ratios, and SEC filings"
        case .portfolio:
            return ResearchMoreDestination.portfolio.subtitle
        case .income:
            return ResearchMoreDestination.income.subtitle
        case .tools:
            return ResearchMoreDestination.tools.subtitle
        case .composition:
            return ResearchMoreDestination.composition.subtitle
        }
    }

    private func rowIcon(for destination: SymbolResearchDestination) -> String {
        if let more = destination.moreDestination {
            return more.systemImage
        }
        return destination.researchTab.systemImage
    }
}

struct ResearchHubLinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .frame(width: 32, height: 32)
                .background(AppColors.accentMuted.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
    }
}

// MARK: - Analysis hub

struct SymbolAnalysisHubTab: View {
    @Environment(AccountContext.self) private var account
    @Environment(AssistantPresenter.self) private var assistant
    @Bindable var overviewVM: SymbolOverviewViewModel
    @Bindable var depthVM: SymbolDepthViewModel
    let bundle: ResearchOverviewBundle?

    private var isEtfLike: Bool {
        let normalized = bundle?.assetType?.uppercased() ?? ""
        return normalized == "ETF" || normalized == "MUTUAL_FUND" || normalized == "INDEX"
    }

    var body: some View {
        ResearchDepthTabShell(tab: .analysis, viewModel: depthVM) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                if let bundle, !bundle.intelligence.signals.isEmpty {
                    SymbolIntelligenceOverviewPanel(signals: bundle.intelligence.signals) { prompt in
                        assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
                    }
                }

                if !isEtfLike {
                    BigPictureSection(
                        summary: bundle?.summary,
                        isLoading: overviewVM.isBigPictureLoading,
                        errorMessage: overviewVM.bigPictureError,
                        onRefresh: {
                            Task { await overviewVM.refreshBigPicture() }
                        }
                    )
                }

                SymbolPatternPredictionContent(viewModel: depthVM)

                if !isEtfLike {
                    SymbolBusinessContent(viewModel: depthVM)
                }
            }
        }
    }
}

// MARK: - Metrics hub

struct SymbolMetricsHubTab: View {
    let assetType: String?

    @Bindable var depthVM: SymbolDepthViewModel

    var body: some View {
        SymbolFundamentalsTab(viewModel: depthVM, assetType: assetType)
    }
}

// MARK: - More hub (legacy menu removed — destinations push from overview)

struct ResearchMoreDetailScreen: View {
    let destination: ResearchMoreDestination
    let symbol: String
    let includesOptions: Bool
    @Bindable var overviewVM: SymbolOverviewViewModel
    @Bindable var depthVM: SymbolDepthViewModel
    @Bindable var positionVM: SymbolPositionViewModel
    @Binding var backtestExploreSection: BacktestExploreSection?
    let primaryStrategy: String?
    var onAssistantPrompt: (String) -> Void

    var body: some View {
        switch destination {
        case .portfolio:
            SymbolPortfolioHubTab(
                positionVM: positionVM,
                depthVM: depthVM,
                symbol: symbol,
                includesOptions: includesOptions,
                onAssistantPrompt: onAssistantPrompt
            )
        case .income:
            SymbolIncomeHubTab(viewModel: depthVM)
        case .tools:
            SymbolBacktestTab(
                exploreSection: $backtestExploreSection,
                viewModel: depthVM,
                primaryStrategy: primaryStrategy,
                marketSharePrice: overviewVM.bundle?.snapshot.price
            )
        case .composition:
            SymbolCompositionTab(viewModel: depthVM)
        }
    }
}

// MARK: - Portfolio hub (positions + options)

struct SymbolPortfolioHubTab: View {
    @Bindable var positionVM: SymbolPositionViewModel
    @Bindable var depthVM: SymbolDepthViewModel
    let symbol: String
    let includesOptions: Bool
    var onAssistantPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            SymbolPositionTab(viewModel: positionVM, showsOptionsPrompt: false) { prompt in
                onAssistantPrompt(prompt)
            }

            if includesOptions {
                SymbolOptionsTab(
                    viewModel: depthVM,
                    symbolPositions: positionVM.positions,
                    assignmentRiskSummary: OptionsRiskHelpers.filterAssignmentRisk(
                        positionVM.assignmentRiskSummary,
                        symbol: symbol
                    ),
                    onAnalyze: onAssistantPrompt
                )
            }
        }
    }
}

// MARK: - Income hub (dividends + earnings)

struct SymbolIncomeHubTab: View {
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            SymbolDividendsTab(viewModel: viewModel)
            SymbolEarningsTab(viewModel: viewModel)
        }
    }
}

// MARK: - Pushed hub screen (single navigation stack)

struct SymbolResearchHubView: View {
    @Environment(AccountContext.self) private var account
    @Environment(AssistantPresenter.self) private var assistant

    let symbolItem: TickerSymbolItem
    let destination: SymbolResearchDestination
    let auth: AuthSession

    @State private var overviewVM: SymbolOverviewViewModel
    @State private var depthVM: SymbolDepthViewModel
    @State private var positionVM: SymbolPositionViewModel
    @State private var primaryStrategy: String?
    @State private var backtestExploreSection: BacktestExploreSection?

    init(
        symbolItem: TickerSymbolItem,
        destination: SymbolResearchDestination,
        auth: AuthSession,
        initialBacktestSection: BacktestExploreSection? = nil
    ) {
        self.symbolItem = symbolItem
        self.destination = destination
        self.auth = auth
        _overviewVM = State(initialValue: SymbolOverviewViewModel(symbol: symbolItem.symbol, auth: auth))
        _depthVM = State(initialValue: SymbolDepthViewModel(symbol: symbolItem.symbol, auth: auth))
        _positionVM = State(initialValue: SymbolPositionViewModel(symbol: symbolItem.symbol, auth: auth))
        _backtestExploreSection = State(initialValue: initialBacktestSection)
    }

    private var includesOptions: Bool {
        SymbolOptionsHelpers.shouldShowOptionsContent(
            positions: positionVM.positions,
            intelligence: depthVM.symbolIntelligence
        )
    }

    var body: some View {
        AppScrollScreen(refresh: { await refreshHub() }) {
            hubContent
        }
        .navigationTitle(destination.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AppToolbarRefreshButton(isRefreshing: isRefreshing) {
                    Task { await refreshHub() }
                }
            }
        }
        .task {
            await loadHub()
            if destination == .portfolio {
                await depthVM.prefetchOptionsIntelligenceIfNeeded(
                    hasOptionPositions: positionVM.hasOptionPositions
                )
            }
            if destination == .tools {
                await loadStrategyContextIfNeeded()
            }
        }
        .appPushedScreenCanvas()
    }

    @ViewBuilder
    private var hubContent: some View {
        switch destination {
        case .analysis:
            SymbolAnalysisHubTab(
                overviewVM: overviewVM,
                depthVM: depthVM,
                bundle: overviewVM.bundle
            )
        case .metrics:
            SymbolMetricsHubTab(
                assetType: overviewVM.bundle?.assetType,
                depthVM: depthVM
            )
        case .news:
            SymbolNewsTab(viewModel: depthVM)
        case .financials:
            SymbolFinancialsTab(viewModel: depthVM)
        case .portfolio, .income, .tools, .composition:
            if let more = destination.moreDestination {
                ResearchMoreDetailScreen(
                    destination: more,
                    symbol: symbolItem.symbol,
                    includesOptions: includesOptions,
                    overviewVM: overviewVM,
                    depthVM: depthVM,
                    positionVM: positionVM,
                    backtestExploreSection: $backtestExploreSection,
                    primaryStrategy: primaryStrategy,
                    onAssistantPrompt: { prompt in
                        assistant.openSymbol(symbolItem.symbol, prompt: prompt, sendImmediately: true)
                    }
                )
            }
        }
    }

    private var isRefreshing: Bool {
        switch destination {
        case .portfolio:
            return positionVM.isLoading
                || positionVM.recentOrdersLoading
                || depthVM.loadingTab == .more
        default:
            return depthVM.loadingTab == destination.researchTab
        }
    }

    private func loadHub() async {
        if destination == .analysis {
            await overviewVM.loadIfNeeded()
        }

        if destination == .portfolio {
            await positionVM.loadIfNeeded()
        }

        if let more = destination.moreDestination {
            await depthVM.loadIfNeeded(.more, more: more)
            if more == .income,
               let event = depthVM.selectedHistoryEvent,
               EarningsSelection.shouldLoadDetail(for: event) {
                await depthVM.loadEarningsDetail(
                    includeAnalysis: account.hasProFeature(.earningsAi),
                    force: true
                )
            }
            return
        }

        await depthVM.loadIfNeeded(destination.researchTab)
    }

    private func refreshHub() async {
        switch destination {
        case .portfolio:
            await positionVM.loadIfNeeded(force: true)
            await depthVM.reload(.more, more: .portfolio)
        case .income:
            await depthVM.reload(.more, more: .income)
            if let event = depthVM.selectedHistoryEvent,
               EarningsSelection.shouldLoadDetail(for: event) {
                await depthVM.loadEarningsDetail(
                    includeAnalysis: account.hasProFeature(.earningsAi),
                    force: true
                )
            }
        case .analysis:
            await overviewVM.reload()
            await depthVM.reload(.analysis)
        default:
            if let more = destination.moreDestination {
                await depthVM.reload(.more, more: more)
            } else {
                await depthVM.reload(destination.researchTab)
            }
        }
    }

    private func loadStrategyContextIfNeeded() async {
        guard destination == .tools, let accessToken = auth.accessToken else { return }
        do {
            let profile = try await StrategyService.fetchProfile(accessToken: accessToken)
            primaryStrategy = profile?.primaryStrategy
        } catch {
            // Optional for backtest defaults.
        }
    }
}
