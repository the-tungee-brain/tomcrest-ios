import SwiftUI

struct SymbolResearchView: View {
    @Environment(AccountContext.self) private var account
    @Environment(AuthSession.self) private var auth
    @Environment(ResearchSymbolBookmarks.self) private var bookmarks
    @Environment(AssistantPresenter.self) private var assistant
    @State private var overviewVM: SymbolOverviewViewModel
    @State private var depthVM: SymbolDepthViewModel
    @State private var positionVM: SymbolPositionViewModel
    @State private var selectedTab: ResearchTab = .overview
    @State private var primaryStrategy: String?
    @State private var strategyCatalogItem: StrategyCatalogItem?
    @State private var strategyRecommendations: StrategyRecommendations?
    @State private var profileSymbols: [String] = []
    @State private var backtestExploreSection: BacktestExploreSection?
    @State private var tabLoadTask: Task<Void, Never>?

    private let initialBacktestSection: BacktestExploreSection?
    private let initialWheelBacktestQuery: WheelBacktestQuery?

    init(
        symbol: String,
        auth: AuthSession,
        initialTab: ResearchTab = .overview,
        initialBacktestSection: BacktestExploreSection? = nil,
        initialWheelBacktestQuery: WheelBacktestQuery? = nil
    ) {
        _overviewVM = State(initialValue: SymbolOverviewViewModel(symbol: symbol, auth: auth))
        _depthVM = State(initialValue: SymbolDepthViewModel(symbol: symbol, auth: auth))
        _positionVM = State(initialValue: SymbolPositionViewModel(symbol: symbol, auth: auth))
        _selectedTab = State(initialValue: initialTab)
        _backtestExploreSection = State(initialValue: initialBacktestSection)
        self.initialBacktestSection = initialBacktestSection
        self.initialWheelBacktestQuery = initialWheelBacktestQuery
    }

    private var availableTabs: [ResearchTab] {
        let tabs = ResearchTab.tabs(
            for: overviewVM.bundle?.assetType,
            primaryStrategy: primaryStrategy
        )
        guard SymbolOptionsHelpers.shouldShowOptionsTab(
            positions: positionVM.positions,
            intelligence: depthVM.symbolIntelligence,
            activeTab: selectedTab
        ) else {
            return tabs.filter { $0 != .options }
        }
        return tabs
    }

    private var companyName: String? {
        guard let name = overviewVM.bundle?.snapshot.name, !name.isEmpty else { return nil }
        return name
    }

    var body: some View {
        VStack(spacing: 0) {
            ResearchTabBar(
                tabs: availableTabs,
                selection: $selectedTab,
                assetType: overviewVM.bundle?.assetType
            )
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 10)
            .background(Token.surfaceSecondary.opacity(0.95))
            .overlay(alignment: .bottom) {
                Divider().overlay(Token.border)
            }

            AppScrollScreen(topPadding: 16, refresh: { await refreshCurrentTab() }) {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
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
                            backtestExploreSection = .wheel
                            selectedTab = .backtest
                        }
                    )

                    tabContent
                }
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
                        Task { await refreshCurrentTab() }
                    }
                }
            }
        }
        .task {
            if let query = initialWheelBacktestQuery {
                depthVM.wheelBacktestQuery = query
            }
            await overviewVM.loadIfNeeded()
            await positionVM.loadIfNeeded()
            await depthVM.prefetchOptionsIntelligenceIfNeeded(
                hasOptionPositions: positionVM.hasOptionPositions
            )
            await loadStrategyContext()
            ensureValidTabSelection()
        }
        .onAppear {
            bookmarks.recordRecent(overviewVM.symbol)
            if selectedTab == .backtest,
               backtestExploreSection == nil,
               let initialBacktestSection {
                backtestExploreSection = initialBacktestSection
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab != .backtest {
                backtestExploreSection = nil
            }
            tabLoadTask?.cancel()
            tabLoadTask = Task {
                if tab == .position || tab == .options {
                    await positionVM.loadIfNeeded()
                }
                if tab != .overview, tab != .position {
                    await depthVM.loadIfNeeded(tab)
                }
                if tab == .earnings {
                    await depthVM.loadEarningsDetail(
                        includeAnalysis: account.hasProFeature(.earningsAi),
                        force: depthVM.selectedHistoryEvent != nil
                    )
                }
            }
        }
        .onChange(of: positionVM.hasOptionPositions) { _, hasOptions in
            Task {
                await depthVM.prefetchOptionsIntelligenceIfNeeded(hasOptionPositions: hasOptions)
                ensureValidTabSelection()
            }
        }
        .onChange(of: depthVM.symbolIntelligence?.symbol) { _, _ in
            ensureValidTabSelection()
        }
        .onChange(of: overviewVM.bundle?.assetType) { _, _ in
            ensureValidTabSelection()
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

    private var researchAssistantPresented: Binding<Bool> {
        Binding(
            get: { assistant.isSymbolPresented(overviewVM.symbol) },
            set: { if !$0 { assistant.dismiss() } }
        )
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            SymbolOverviewTab(
                viewModel: overviewVM,
                positionViewModel: positionVM,
                bundle: overviewVM.bundle
            ) { prompt in
                assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
            }
        case .position:
            SymbolPositionTab(viewModel: positionVM) { prompt in
                if prompt == "__open_options_tab__" {
                    selectedTab = .options
                } else {
                    assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
                }
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
        case .earnings:
            SymbolEarningsTab(viewModel: depthVM)
        case .news:
            SymbolNewsTab(viewModel: depthVM)
        case .business:
            SymbolBusinessTab(viewModel: depthVM)
        case .dividends:
            SymbolDividendsTab(viewModel: depthVM)
        case .fundamentals:
            SymbolFundamentalsTab(viewModel: depthVM, assetType: overviewVM.bundle?.assetType)
        case .financials:
            SymbolFinancialsTab(viewModel: depthVM)
        case .composition:
            SymbolCompositionTab(viewModel: depthVM)
        case .trend:
            SymbolPatternPredictionTab(viewModel: depthVM)
        case .backtest:
            SymbolBacktestTab(
                exploreSection: $backtestExploreSection,
                viewModel: depthVM,
                primaryStrategy: primaryStrategy,
                marketSharePrice: overviewVM.bundle?.snapshot.price
            )
        }
    }

    private var isRefreshing: Bool {
        if selectedTab == .overview {
            return overviewVM.isLoading
        }
        if selectedTab == .position {
            return positionVM.isLoading || positionVM.recentOrdersLoading
        }
        if selectedTab == .options {
            return depthVM.loadingTab == .options || positionVM.isLoading
        }
        return depthVM.loadingTab == selectedTab
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
                strategyRecommendations = try await StrategyService.fetchRecommendations(
                    strategyId: strategyId,
                    accessToken: accessToken,
                    symbol: overviewVM.symbol
                )
            }
        } catch {
            // Strategy context is optional on research pages.
        }
    }

    private func refreshCurrentTab() async {
        if selectedTab == .overview {
            await overviewVM.reload()
        } else if selectedTab == .position || selectedTab == .options {
            await positionVM.loadIfNeeded(force: true)
            if selectedTab == .options {
                await depthVM.reload(.options)
            }
        } else {
            await depthVM.reload(selectedTab)
            if selectedTab == .earnings {
                await depthVM.loadEarningsDetail(
                    includeAnalysis: account.hasProFeature(.earningsAi),
                    force: true
                )
            }
        }
    }

    private func ensureValidTabSelection() {
        let tabs = availableTabs
        if !tabs.contains(selectedTab), let first = tabs.first {
            selectedTab = first
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
