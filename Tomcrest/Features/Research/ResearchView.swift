import SwiftUI

struct ResearchView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(ResearchSymbolBookmarks.self) private var bookmarks
    @State private var viewModel: ResearchViewModel?
    @State private var selectedSymbol: TickerSymbolItem?

    private let exampleSymbols = ["NVDA", "SPY", "AAPL", "SCHD"]

    private var researchOnboardingComplete: Bool {
        !bookmarks.recentSymbols.isEmpty
            && !bookmarks.watchlist.isEmpty
            && ResearchSymbolStorage.hasUsedResearchChat()
    }

    var body: some View {
        NavigationStack {
            AppScrollScreen {
                if let viewModel {
                    if !OnboardingStorage.isResearchOnboardingDismissed(),
                       !researchOnboardingComplete {
                        ResearchOnboardingCard(
                            hasOpenedSymbol: !bookmarks.recentSymbols.isEmpty,
                            hasWatchlist: !bookmarks.watchlist.isEmpty,
                            usedChat: ResearchSymbolStorage.hasUsedResearchChat(),
                            onDismiss: { OnboardingStorage.dismissResearchOnboarding() }
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
            .task {
                if viewModel == nil {
                    viewModel = ResearchViewModel(auth: auth)
                }
            }
        }
    }

    @ViewBuilder
    private var quickAccessSection: some View {
        if !bookmarks.watchlist.isEmpty {
            ResearchWatchlistSection(symbols: bookmarks.watchlist) { symbol in
                openSymbol(symbol)
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(exampleSymbols, id: \.self) { symbol in
                        AppChip(title: symbol) {
                            openSymbol(symbol)
                        }
                    }
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
}

private struct SymbolSearchRowContent: View {
    let item: TickerSymbolItem

    var body: some View {
        HStack(spacing: 12) {
            SymbolAvatar(symbol: item.symbol, size: 32)

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
    }
}
