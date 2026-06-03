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
        ResearchTab.tabs(for: overviewVM.bundle?.assetType)
    }

    private var companyName: String? {
        guard let name = overviewVM.bundle?.snapshot.name, !name.isEmpty else { return nil }
        return name
    }

    var body: some View {
        AppScrollScreen(topPadding: 16, refresh: { await overviewVM.reload() }) {
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

                SymbolOverviewTab(
                    viewModel: overviewVM,
                    positionViewModel: positionVM,
                    bundle: overviewVM.bundle,
                    availableTabs: availableTabs,
                    symbolItem: symbolItem,
                    onOpenHub: onOpenHub
                ) { prompt in
                    assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
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
                    AppToolbarRefreshButton(isRefreshing: overviewVM.isLoading) {
                        Task { await overviewVM.reload() }
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
        .task(id: overviewVM.bundle?.symbol) {
            guard overviewVM.bundle != nil else { return }
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

    private var researchAssistantPresented: Binding<Bool> {
        Binding(
            get: { assistant.isSymbolPresented(overviewVM.symbol) },
            set: { if !$0 { assistant.dismiss() } }
        )
    }

    private func applyInitialDestinationIfNeeded() {
        guard !didApplyInitialDestination else { return }
        didApplyInitialDestination = true

        if let destination = SymbolResearchDestination.from(
            tab: initialTab,
            more: initialMoreDestination
        ) {
            onOpenHub(destination)
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
