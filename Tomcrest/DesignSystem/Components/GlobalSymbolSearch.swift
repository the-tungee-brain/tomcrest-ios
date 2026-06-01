import SwiftUI

struct GlobalSymbolSearchSheet: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ResearchViewModel?
    @State private var selectedSymbol: TickerSymbolItem?

    var body: some View {
        NavigationStack {
            AppScrollScreen {
                AppSearchField(
                    placeholder: "Search tickers",
                    text: Binding(
                        get: { viewModel?.query ?? "" },
                        set: { viewModel?.updateQuery($0) }
                    ),
                    isLoading: viewModel?.isSearching ?? false,
                    onSubmit: {
                        if let first = viewModel?.results.first {
                            openSymbolItem(first)
                        }
                    }
                )

                if let viewModel {
                    if let error = viewModel.searchError {
                        AppInlineBanner(message: error, tone: .error)
                    }

                    if !viewModel.results.isEmpty {
                        AppGroupedList {
                            ForEach(Array(viewModel.results.prefix(12).enumerated()), id: \.element.id) { index, item in
                                Button {
                                    openSymbolItem(item)
                                } label: {
                                    GlobalSymbolSearchRow(item: item)
                                }
                                .buttonStyle(.plain)

                                if index < min(viewModel.results.count, 12) - 1 {
                                    AppGroupedDivider()
                                }
                            }
                        }
                    } else if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              viewModel.isSearching == false {
                        AppInlineBanner(
                            message: "No symbols found for \"\(viewModel.query.uppercased())\".",
                            tone: .neutral
                        )
                    }
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

private struct GlobalSymbolSearchRow: View {
    let item: TickerSymbolItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
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
