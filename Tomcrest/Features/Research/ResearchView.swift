import SwiftUI

struct ResearchView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(ResearchSymbolBookmarks.self) private var bookmarks
    @Environment(WatchlistStore.self) private var watchlistStore
    @State private var viewModel: ResearchViewModel?
    @State private var selectedSymbol: TickerSymbolItem?
    @State private var path: [ResearchDestination] = []
    @State private var showsResearchOnboarding = !OnboardingStorage.isResearchOnboardingDismissed()

    private let exampleSymbols = ["NVDA", "SPY", "AAPL", "SCHD"]

    private var researchOnboardingComplete: Bool {
        !bookmarks.recentSymbols.isEmpty
            && watchlistStore.hasSymbols
            && ResearchSymbolStorage.hasUsedResearchChat()
    }

    var body: some View {
        AppRoutedNavigationCanvasStack(path: $path) {
            AppScrollScreen {
                if let viewModel {
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

                    AppSearchField(
                        placeholder: "Search tickers",
                        text: Binding(
                            get: { viewModel.query },
                            set: { viewModel.updateQuery($0) }
                        ),
                        isLoading: viewModel.isSearching,
                        onSubmit: {
                            if let first = viewModel.results.first {
                                openSymbolItem(first)
                            }
                        }
                    )

                    if viewModel.query.isEmpty {
                        researchExploreSection
                        quickAccessSection
                    }

                    searchResults(viewModel)

                    if viewModel.query.isEmpty, !bookmarks.hasQuickAccess {
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
            .appRootNavigation("Research")
            .navigationDestination(item: $selectedSymbol) { item in
                SymbolResearchView(symbol: item.symbol, auth: auth)
            }
            .navigationDestination(for: ResearchDestination.self) { destination in
                switch destination {
                case .watchlist:
                    WatchlistHubScreen { symbol in
                        openSymbol(symbol)
                    }
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = ResearchViewModel(auth: auth)
                }
            }
        }
    }

    @ViewBuilder
    private var researchExploreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Explore")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            NavigationLink(value: ResearchDestination.watchlist) {
                PortfolioQuickLinkRow(
                    icon: "star.fill",
                    title: "Watchlist",
                    subtitle: watchlistStore.hasSymbols
                        ? "\(watchlistStore.allTickers.count) saved for research"
                        : "Save symbols from search",
                    badge: watchlistStore.allTickers.count
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
    }

    @ViewBuilder
    private var quickAccessSection: some View {
        if !watchlistStore.allTickers.isEmpty {
            ResearchWatchlistSection(symbols: watchlistStore.allTickers) { symbol in
                openSymbol(symbol)
            } onViewAll: {
                path.append(.watchlist)
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

    @ViewBuilder
    private func searchResults(_ viewModel: ResearchViewModel) -> some View {
        if let error = viewModel.searchError {
            AppInlineBanner(message: error, tone: .error)
        } else if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !viewModel.isSearching,
                  viewModel.results.isEmpty {
            AppInlineBanner(
                message: "No symbols found for \"\(viewModel.query.uppercased())\".",
                tone: .neutral
            )
        } else if !viewModel.results.isEmpty {
            AppGroupedList {
                ForEach(Array(viewModel.results.prefix(12).enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 0) {
                        Button {
                            openSymbolItem(item)
                        } label: {
                            SymbolSearchRowContent(item: item)
                        }
                        .buttonStyle(.plain)

                        WatchlistToggleButton(symbol: item.symbol)
                            .padding(.trailing, 8)
                    }

                    if index < min(viewModel.results.count, 12) - 1 {
                        AppGroupedDivider()
                    }
                }
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

    private func openSymbolItem(_ item: TickerSymbolItem) {
        bookmarks.recordRecent(item.symbol)
        selectedSymbol = item
    }

    private func openSymbol(_ symbol: String) {
        bookmarks.recordRecent(symbol)
        selectedSymbol = TickerSymbolItem(
            symbol: symbol.uppercased(),
            title: nil,
            assetType: nil,
            logoURL: nil
        )
    }

    private func dismissResearchOnboarding() {
        OnboardingStorage.dismissResearchOnboarding()
        withAnimation(.easeOut(duration: 0.2)) {
            showsResearchOnboarding = false
        }
    }
}

private struct SymbolSearchRowContent: View {
    let item: TickerSymbolItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Token.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(Token.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Token.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if let title = item.title, !title.isEmpty {
            return title
        }
        if let assetType = item.assetType {
            return AssetTypeLabel.display(assetType)
        }
        return ""
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
