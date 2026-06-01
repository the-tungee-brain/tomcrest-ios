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
    @State private var moreDestination: ResearchMoreDestination?
    @State private var primaryStrategy: String?
    @State private var strategyCatalogItem: StrategyCatalogItem?
    @State private var strategyRecommendations: StrategyRecommendations?
    @State private var profileSymbols: [String] = []
    @State private var backtestExploreSection: BacktestExploreSection?
    @State private var tabLoadTask: Task<Void, Never>?

    private let initialMoreDestination: ResearchMoreDestination?
    private let initialBacktestSection: BacktestExploreSection?
    private let initialWheelBacktestQuery: WheelBacktestQuery?

    init(
        symbol: String,
        auth: AuthSession,
        initialTab: ResearchTab = .overview,
        initialMoreDestination: ResearchMoreDestination? = nil,
        initialBacktestSection: BacktestExploreSection? = nil,
        initialWheelBacktestQuery: WheelBacktestQuery? = nil
    ) {
        _overviewVM = State(initialValue: SymbolOverviewViewModel(symbol: symbol, auth: auth))
        _depthVM = State(initialValue: SymbolDepthViewModel(symbol: symbol, auth: auth))
        _positionVM = State(initialValue: SymbolPositionViewModel(symbol: symbol, auth: auth))
        _selectedTab = State(initialValue: initialTab)
        _moreDestination = State(initialValue: initialMoreDestination)
        _backtestExploreSection = State(initialValue: initialBacktestSection)
        self.initialMoreDestination = initialMoreDestination
        self.initialBacktestSection = initialBacktestSection
        self.initialWheelBacktestQuery = initialWheelBacktestQuery
    }

    private var availableTabs: [ResearchTab] {
        ResearchTab.tabs(for: overviewVM.bundle?.assetType)
    }

    private var includesOptions: Bool {
        SymbolOptionsHelpers.shouldShowOptionsContent(
            positions: positionVM.positions,
            intelligence: depthVM.symbolIntelligence
        )
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
                                backtestExploreSection = .wheel
                                moreDestination = .tools
                                selectedTab = .more
                            }
                        )
                    }

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
            await loadCurrentTabIfNeeded()
        }
        .onAppear {
            bookmarks.recordRecent(overviewVM.symbol)
            if selectedTab == .more,
               moreDestination == .tools,
               backtestExploreSection == nil,
               let initialBacktestSection {
                backtestExploreSection = initialBacktestSection
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab != .more {
                moreDestination = nil
                backtestExploreSection = nil
            }
            tabLoadTask?.cancel()
            tabLoadTask = Task { await loadTabData(tab: tab, more: moreDestination) }
        }
        .onChange(of: moreDestination) { _, destination in
            guard selectedTab == .more, let destination else { return }
            tabLoadTask?.cancel()
            tabLoadTask = Task { await loadTabData(tab: .more, more: destination) }
        }
        .onChange(of: positionVM.hasOptionPositions) { _, hasOptions in
            Task {
                await depthVM.prefetchOptionsIntelligenceIfNeeded(hasOptionPositions: hasOptions)
            }
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
                bundle: overviewVM.bundle,
                availableTabs: availableTabs,
                selectedTab: $selectedTab,
                onOpenMore: { destination in
                    moreDestination = destination
                    selectedTab = .more
                }
            ) { prompt in
                assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
            }
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
        case .more:
            ResearchMoreTab(
                symbol: overviewVM.symbol,
                assetType: overviewVM.bundle?.assetType,
                includesOptions: includesOptions,
                destination: $moreDestination,
                overviewVM: overviewVM,
                depthVM: depthVM,
                positionVM: positionVM,
                backtestExploreSection: $backtestExploreSection,
                primaryStrategy: primaryStrategy,
                onAssistantPrompt: { prompt in
                    assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
                }
            )
        }
    }

    private var isRefreshing: Bool {
        switch selectedTab {
        case .overview:
            return overviewVM.isLoading
        case .more where moreDestination == .portfolio:
            return positionVM.isLoading
                || positionVM.recentOrdersLoading
                || depthVM.loadingTab == .more
        default:
            return depthVM.loadingTab == selectedTab
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

    private func loadCurrentTabIfNeeded() async {
        await loadTabData(tab: selectedTab, more: moreDestination)
    }

    private func loadTabData(tab: ResearchTab, more: ResearchMoreDestination?) async {
        if tab == .more, more == .portfolio {
            await positionVM.loadIfNeeded()
        }

        if tab == .overview {
            return
        }

        if tab == .analysis {
            await depthVM.loadIfNeeded(.analysis)
            return
        }

        if tab == .more {
            if let more {
                await depthVM.loadIfNeeded(.more, more: more)
                if more == .income {
                    await depthVM.loadEarningsDetail(
                        includeAnalysis: account.hasProFeature(.earningsAi),
                        force: depthVM.selectedHistoryEvent != nil
                    )
                }
            }
            return
        }

        await depthVM.loadIfNeeded(tab)
    }

    private func refreshCurrentTab() async {
        switch selectedTab {
        case .overview:
            await overviewVM.reload()
        case .more where moreDestination == .portfolio:
            await positionVM.loadIfNeeded(force: true)
            await depthVM.reload(.more, more: .portfolio)
        case .more where moreDestination == .income:
            await depthVM.reload(.more, more: .income)
            await depthVM.loadEarningsDetail(
                includeAnalysis: account.hasProFeature(.earningsAi),
                force: true
            )
        default:
            await depthVM.reload(selectedTab, more: moreDestination)
        }
    }

    private func ensureValidTabSelection() {
        let tabs = availableTabs
        if !tabs.contains(selectedTab), let first = tabs.first {
            selectedTab = first
            moreDestination = nil
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
