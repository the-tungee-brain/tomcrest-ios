import SwiftUI

struct GlobalSymbolSearchSheet: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ResearchViewModel?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            AppScrollScreen {
                AppSearchField(
                    placeholder: "Search tickers",
                    text: $searchText,
                    isLoading: viewModel?.isSearching ?? false,
                    onSubmit: {
                        if let first = viewModel?.results.first {
                            openSymbolItem(first)
                        }
                    },
                    focus: $isSearchFocused
                )
                .onChange(of: searchText) { _, newValue in
                    viewModel?.updateQuery(newValue)
                }

                if let viewModel {
                    ResearchSearchResultsSection(
                        viewModel: viewModel,
                        searchText: searchText,
                        watchlistSymbols: [],
                        showsWatchlistToggle: false,
                        onSelect: openSymbolItem
                    )
                }
            }
            .navigationTitle("Search symbols")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ResearchViewModel(auth: auth)
            }
        }
    }

    private func openSymbolItem(_ item: TickerSymbolItem) {
        router.openSymbol(item.symbol)
        dismiss()
    }
}

struct GlobalSymbolSearchToolbarButton: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.showGlobalSymbolSearch = true
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
        }
        .accessibilityLabel("Search symbols")
    }
}
