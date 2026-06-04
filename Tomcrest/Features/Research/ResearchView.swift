import SwiftUI

struct ResearchView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(ResearchSymbolBookmarks.self) private var bookmarks
    @Environment(WatchlistStore.self) private var watchlistStore
    @Environment(TabBarReselectCoordinator.self) private var tabReselect
    @State private var viewModel: ResearchViewModel?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var path: [ResearchRoute] = []
    @State private var scrollToTopToken = 0
    @State private var showsResearchOnboarding = !OnboardingStorage.isResearchOnboardingDismissed()
    @State private var mbAlertsEnabled = true

    private let exampleSymbols = ["NVDA", "SPY", "AAPL", "SCHD"]

    private var researchOnboardingComplete: Bool {
        !bookmarks.recentSymbols.isEmpty
            && watchlistStore.hasSymbols
            && ResearchSymbolStorage.hasUsedResearchChat()
    }

    private var showsBrowseSections: Bool {
        searchText.isEmpty && !isSearchFocused
    }

    var body: some View {
        AppRoutedNavigationCanvasStack(path: $path) {
            AppScrollScreen(
                scrollToToken: $scrollToTopToken,
                scrollAnchor: AppScrollAnchor.top
            ) {
                Color.clear
                    .appTopScrollAnchor()

                if let viewModel {
                    AppSearchField(
                        placeholder: "Search tickers",
                        text: $searchText,
                        isLoading: viewModel.isSearching,
                        onSubmit: {
                            if let first = sortedSearchResults(viewModel.results).first {
                                openSymbolItem(first)
                            }
                        },
                        focus: $isSearchFocused
                    )
                    .onChange(of: searchText) { _, newValue in
                        viewModel.updateQuery(newValue)
                    }

                    if showsBrowseSections {
                        quickAccessSection

                        if showsResearchOnboarding, !researchOnboardingComplete {
                            ResearchOnboardingCard(
                                hasOpenedSymbol: !bookmarks.recentSymbols.isEmpty,
                                hasWatchlist: watchlistStore.hasSymbols,
                                usedChat: ResearchSymbolStorage.hasUsedResearchChat(),
                                onDismiss: dismissResearchOnboarding
                            )
                        }

                        StrategyPlaybookQuickLinksSection { symbol in
                            openSymbol(symbol)
                        }
                    }

                    ResearchSearchResultsSection(
                        viewModel: viewModel,
                        searchText: searchText,
                        watchlistSymbols: Set(watchlistStore.allTickers.map { $0.uppercased() }),
                        onSelect: openSymbolItem
                    )

                    if showsBrowseSections, !bookmarks.hasQuickAccess {
                        examplesSection
                    }
                } else {
                    AppSearchField(
                        placeholder: "Search tickers",
                        text: .constant(""),
                        isLoading: true
                    )
                }
            }
            .animation(nil, value: showsBrowseSections)
            .appRootNavigation("Research")
            .toolbar {
                if mbAlertsEnabled {
                    ToolbarItem(placement: .topBarTrailing) {
                        MomentumBreakoutNotificationBell {
                            path.append(.momentumBreakoutAlerts)
                        }
                    }
                }
            }
            .onChange(of: tabReselect.researchReselectCount) { _, _ in
                path = []
                isSearchFocused = false
                scrollToTopToken += 1
            }
            .navigationDestination(for: ResearchRoute.self) { route in
                switch route {
                case .watchlist:
                    WatchlistHubScreen { symbol in
                        openSymbol(symbol)
                    }
                case .momentumBreakoutAlerts:
                    MomentumBreakoutAlertsScreen()
                case .symbol(let item):
                    SymbolResearchView(symbolItem: item, auth: auth) { hub in
                        path.append(.symbolHub(item, hub))
                    }
                case .symbolHub(let item, let hub):
                    SymbolResearchHubView(
                        symbolItem: item,
                        destination: hub,
                        auth: auth
                    )
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = ResearchViewModel(auth: auth)
                }
                if let token = auth.accessToken, !token.isEmpty {
                    if let status = try? await MomentumBreakoutAlertService.fetchFeatureStatus(
                        accessToken: token
                    ) {
                        mbAlertsEnabled = status.flags.alertsEnabled
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            if mbAlertsEnabled {
                NavigationLink(value: ResearchRoute.momentumBreakoutAlerts) {
                    PortfolioQuickLinkRow(
                        icon: "bell.badge",
                        title: "Momentum Breakout trade plans",
                        subtitle: "Active alerts, history, and notifications"
                    )
                }
                .buttonStyle(.plain)
                .background(AppColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.panelBorder, lineWidth: 1)
                }
            }

            if !watchlistStore.allTickers.isEmpty {
                ResearchWatchlistSection(symbols: watchlistStore.allTickers) { symbol in
                    openSymbol(symbol)
                } onViewAll: {
                    path.append(.watchlist)
                }
            } else {
                NavigationLink(value: ResearchRoute.watchlist) {
                    PortfolioQuickLinkRow(
                        icon: "star.fill",
                        title: "Watchlist",
                        subtitle: "Save symbols from search"
                    )
                }
                .buttonStyle(.plain)
                .background(AppColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.panelBorder, lineWidth: 1)
                }
            }

            if !bookmarks.recentWithoutWatchlist.isEmpty {
                ResearchRecentSymbolsSection(
                    symbols: bookmarks.recentWithoutWatchlist,
                    onClear: { bookmarks.clearRecent() },
                    onSelect: { openSymbol($0) }
                )
            }
        }
    }

    private var examplesSection: some View {
        AppScreenSection(title: "Try an example") {
            AppWrappingChipGrid(items: exampleSymbols, minimumChipWidth: 72) { symbol in
                AppChip(title: symbol) {
                    openSymbol(symbol)
                }
            }
        }
    }

    private func sortedSearchResults(_ results: [TickerSymbolItem]) -> [TickerSymbolItem] {
        let watchlist = Set(watchlistStore.allTickers.map { $0.uppercased() })
        return results.sorted { lhs, rhs in
            let lhsWatching = watchlist.contains(lhs.symbol.uppercased())
            let rhsWatching = watchlist.contains(rhs.symbol.uppercased())
            if lhsWatching != rhsWatching {
                return lhsWatching
            }
            return false
        }
    }

    private func openSymbolItem(_ item: TickerSymbolItem) {
        bookmarks.recordRecent(item.symbol)
        path.append(.symbol(item))
    }

    private func openSymbol(_ symbol: String) {
        bookmarks.recordRecent(symbol)
        path.append(
            .symbol(
                TickerSymbolItem(
                    symbol: symbol.uppercased(),
                    title: nil,
                    assetType: nil,
                    logoURL: nil
                )
            )
        )
    }

    private func dismissResearchOnboarding() {
        OnboardingStorage.dismissResearchOnboarding()
        withAnimation(.easeOut(duration: 0.2)) {
            showsResearchOnboarding = false
        }
    }
}

#Preview {
    AppPreview.environments {
        ResearchView()
            .environment(AuthSession())
            .environment(AccountContext())
            .environment(ResearchSymbolBookmarks())
            .environment(WatchlistStore())
    }
}
