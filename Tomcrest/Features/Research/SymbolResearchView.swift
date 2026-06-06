import SwiftUI

struct SymbolResearchView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(ResearchSymbolBookmarks.self) private var bookmarks
    @Environment(AssistantPresenter.self) private var assistant

    @State private var overviewVM: SymbolOverviewViewModel
    @State private var depthVM: SymbolDepthViewModel
    @State private var positionVM: SymbolPositionViewModel
    @State private var primaryStrategy: String?
    @State private var strategyCatalogItem: StrategyCatalogItem?
    @State private var strategyRecommendations: StrategyRecommendations?
    @State private var profileSymbols: [String] = []
    @State private var didApplyInitialDestination = false
    @State private var selectedPrimaryTab: ResearchPrimaryTab

    let symbolItem: TickerSymbolItem
    var onOpenHub: (SymbolResearchDestination) -> Void

    private let initialTab: ResearchTab
    private let initialMoreDestination: ResearchMoreDestination?
    private let initialWheelBacktestQuery: WheelBacktestQuery?

    init(
        symbolItem: TickerSymbolItem,
        auth: AuthSession,
        onOpenHub: @escaping (SymbolResearchDestination) -> Void = { _ in },
        initialTab: ResearchTab = .overview,
        initialMoreDestination: ResearchMoreDestination? = nil,
        initialWheelBacktestQuery: WheelBacktestQuery? = nil
    ) {
        self.symbolItem = symbolItem
        self.onOpenHub = onOpenHub
        _overviewVM = State(initialValue: SymbolOverviewViewModel(symbol: symbolItem.symbol, auth: auth))
        _depthVM = State(initialValue: SymbolDepthViewModel(symbol: symbolItem.symbol, auth: auth))
        _positionVM = State(initialValue: SymbolPositionViewModel(symbol: symbolItem.symbol, auth: auth))
        _selectedPrimaryTab = State(
            initialValue: ResearchPrimaryTab.resolve(tab: initialTab, more: initialMoreDestination)
        )
        self.initialTab = initialTab
        self.initialMoreDestination = initialMoreDestination
        self.initialWheelBacktestQuery = initialWheelBacktestQuery
    }

    /// Convenience initializer for call sites that only have a symbol string.
    init(
        symbol: String,
        auth: AuthSession,
        onOpenHub: @escaping (SymbolResearchDestination) -> Void = { _ in },
        initialTab: ResearchTab = .overview,
        initialMoreDestination: ResearchMoreDestination? = nil,
        initialWheelBacktestQuery: WheelBacktestQuery? = nil
    ) {
        self.init(
            symbolItem: TickerSymbolItem(
                symbol: symbol.uppercased(),
                title: nil,
                assetType: nil,
                logoURL: nil
            ),
            auth: auth,
            onOpenHub: onOpenHub,
            initialTab: initialTab,
            initialMoreDestination: initialMoreDestination,
            initialWheelBacktestQuery: initialWheelBacktestQuery
        )
    }

    private var availableTabs: [ResearchTab] {
        ResearchTab.tabs(for: assetType)
    }

    private var primaryTabs: [ResearchPrimaryTab] {
        ResearchPrimaryTab.visibleTabs
    }

    private var assetType: String? {
        overviewVM.bundle?.assetType ?? symbolItem.assetType
    }

    private var companyName: String? {
        guard let name = (overviewVM.snapshot ?? overviewVM.bundle?.snapshot)?.name,
              !name.isEmpty else { return nil }
        return name
    }

    var body: some View {
        AppScrollScreen(topPadding: 16, refresh: { await refreshSelectedPrimaryTab() }) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                if primaryStrategy != nil {
                    StrategySymbolPlaybookStrip(
                        symbol: overviewVM.symbol,
                        strategyId: primaryStrategy,
                        catalogItem: strategyCatalogItem,
                        recommendations: strategyRecommendations,
                        profileSymbols: profileSymbols,
                        onRunAction: { action in
                            guard let primaryStrategy else { return }
                            assistant.openSymbol(overviewVM.symbol)
                            Task {
                                await overviewVM.sendPlaybookAsk(action: action, strategyId: primaryStrategy)
                            }
                        },
                        onOpenBacktest: {
                            onOpenHub(.tools)
                        }
                    )
                }

                ResearchTabBar(
                    tabs: primaryTabs,
                    selection: $selectedPrimaryTab,
                    assetType: assetType
                )

                selectedTabContent
            }
        }
        .appDetailNavigation()
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(overviewVM.symbol)
                        .font(.headline)
                        .foregroundStyle(Token.textPrimary)
                    if let companyName {
                        Text(companyName)
                            .font(.caption)
                            .foregroundStyle(Token.textSecondary)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    WatchlistToggleButton(symbol: overviewVM.symbol, companyName: companyName)
                    AppToolbarRefreshButton(isRefreshing: isRefreshing) {
                        Task { await refreshSelectedPrimaryTab() }
                    }
                }
            }
        }
        .task {
            if let query = initialWheelBacktestQuery {
                depthVM.wheelBacktestQuery = query
            }
            await overviewVM.loadIfNeeded()
        }
        .task(id: selectedPrimaryTab) {
            await loadSelectedPrimaryTab()
        }
        .task(id: overviewVM.snapshot?.symbol ?? overviewVM.bundle?.symbol) {
            guard overviewVM.snapshot != nil || overviewVM.bundle != nil else { return }
            await loadStrategyContext()
        }
        .onAppear {
            bookmarks.recordRecent(overviewVM.symbol)
            applyInitialDestinationIfNeeded()
        }
        .appPushedScreenCanvas()
        .overlay(alignment: .bottomTrailing) {
            FloatingAssistantButton {
                assistant.openSymbol(overviewVM.symbol)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: researchAssistantPresented) {
            ResearchAssistantSheet(viewModel: overviewVM)
        }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedPrimaryTab {
        case .overview:
            overviewContent
        case .analysis:
            SymbolAnalysisHubTab(
                overviewVM: overviewVM,
                depthVM: depthVM,
                bundle: overviewVM.bundle
            )
        case .events:
            SymbolNewsTab(viewModel: depthVM)
        case .positions:
            SymbolPositionTab(viewModel: positionVM, showsOptionsPrompt: false) { prompt in
                handlePositionPrompt(prompt)
            }
        case .options:
            SymbolOptionsTab(
                viewModel: depthVM,
                symbolPositions: positionVM.positions,
                assignmentRiskSummary: OptionsRiskHelpers.filterAssignmentRisk(
                    positionVM.assignmentRiskSummary,
                    symbol: overviewVM.symbol
                )
            ) { prompt in
                assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
            }
        case .more:
            ResearchMoreLinks(
                assetType: assetType,
                availableTabs: availableTabs,
                onOpenHub: onOpenHub
            )
        }
    }

    private var overviewContent: some View {
        SymbolOverviewTab(
            viewModel: overviewVM,
            positionViewModel: positionVM,
            bundle: overviewVM.bundle,
            availableTabs: availableTabs,
            assetType: assetType,
            symbolItem: symbolItem,
            showsExploreLinks: false,
            onOpenHub: onOpenHub
        ) { prompt in
            assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
        }
    }

    private var isRefreshing: Bool {
        switch selectedPrimaryTab {
        case .overview:
            return overviewVM.isLoading
        case .analysis:
            return depthVM.loadingTab == .analysis
        case .events:
            return depthVM.loadingTab == .news
        case .positions:
            return positionVM.isLoading
                || positionVM.positionGuidanceLoading
                || positionVM.recentOrdersLoading
        case .options:
            return depthVM.loadingTab == .more || positionVM.isLoading
        case .more:
            return false
        }
    }

    private func loadSelectedPrimaryTab() async {
        switch selectedPrimaryTab {
        case .overview:
            await overviewVM.loadIfNeeded()
        case .analysis:
            async let overview: Void = overviewVM.loadIfNeeded()
            async let depth: Void = depthVM.loadIfNeeded(.analysis)
            _ = await (overview, depth)
        case .events:
            await depthVM.loadIfNeeded(.news)
        case .positions:
            async let position: Void = positionVM.loadIfNeeded()
            async let guidance: Void = positionVM.loadPositionGuidanceIfNeeded()
            _ = await (position, guidance)
        case .options:
            async let position: Void = positionVM.loadIfNeeded()
            async let depth: Void = depthVM.loadIfNeeded(.more, more: .portfolio)
            _ = await (position, depth)
            await depthVM.prefetchOptionsIntelligenceIfNeeded(
                hasOptionPositions: positionVM.hasOptionPositions
            )
        case .more:
            break
        }
    }

    private func refreshSelectedPrimaryTab() async {
        switch selectedPrimaryTab {
        case .overview:
            await overviewVM.reload()
        case .analysis:
            await overviewVM.reload()
            await depthVM.reload(.analysis)
        case .events:
            await depthVM.reload(.news)
        case .positions:
            async let position: Void = positionVM.loadIfNeeded(force: true)
            async let guidance: Void = positionVM.loadPositionGuidanceIfNeeded(force: true)
            _ = await (position, guidance)
        case .options:
            async let position: Void = positionVM.loadIfNeeded(force: true)
            async let depth: Void = depthVM.reload(.more, more: .portfolio)
            _ = await (position, depth)
        case .more:
            break
        }
    }

    private func handlePositionPrompt(_ prompt: String) {
        if prompt == "__open_portfolio_options__" {
            selectedPrimaryTab = .options
        } else {
            assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
        }
    }

    private var researchAssistantPresented: Binding<Bool> {
        Binding(
            get: { assistant.isSymbolPresented(overviewVM.symbol) },
            set: { if !$0 { assistant.dismiss() } }
        )
    }

    private func applyInitialDestinationIfNeeded() {
        guard !didApplyInitialDestination else { return }
        didApplyInitialDestination = true
        selectedPrimaryTab = ResearchPrimaryTab.resolve(tab: initialTab, more: initialMoreDestination)

        guard shouldPushInitialDestination else { return }

        if let destination = SymbolResearchDestination.from(
            tab: initialTab,
            more: initialMoreDestination
        ) {
            onOpenHub(destination)
        }
    }

    private var shouldPushInitialDestination: Bool {
        switch (initialTab, initialMoreDestination) {
        case (.overview, _),
             (.analysis, _),
             (.news, _),
             (.more, .portfolio),
             (.more, .options):
            return false
        default:
            return true
        }
    }

    private func loadStrategyContext() async {
        guard let accessToken = auth.accessToken else { return }
        do {
            async let profileTask = StrategyService.fetchProfile(accessToken: accessToken)
            async let catalogTask = StrategyService.fetchCatalog(accessToken: accessToken)
            let profile = try await profileTask
            let catalog = try await catalogTask
            primaryStrategy = profile?.primaryStrategy
            profileSymbols = StrategyPlaybookHelpers.symbols(from: profile)
            if let strategyId = profile?.primaryStrategy {
                strategyCatalogItem = catalog.first { $0.id == strategyId }
                Task { @MainActor in
                    strategyRecommendations = try? await StrategyService.fetchRecommendations(
                        strategyId: strategyId,
                        accessToken: accessToken,
                        symbol: overviewVM.symbol
                    )
                }
            }
        } catch {
            // Strategy context is optional on research pages.
        }
    }
}

#Preview {
    AppPreview.environments {
        NavigationStack {
            SymbolResearchView(symbol: "AAPL", auth: AuthSession())
        }
        .environment(AuthSession())
        .environment(AccountContext())
        .environment(ResearchSymbolBookmarks())
        .environment(WatchlistStore())
        .environment(AssistantPresenter())
    }
}
