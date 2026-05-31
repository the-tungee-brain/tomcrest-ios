import SwiftUI

struct ResearchView: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel: ResearchViewModel?
    @State private var selectedSymbol: TickerSymbolItem?

    private let exampleSymbols = ["NVDA", "SPY", "AAPL", "SCHD"]

    var body: some View {
        NavigationStack {
            AppScrollScreen {
                if let viewModel {
                    if !OnboardingStorage.isResearchOnboardingDismissed() {
                        ResearchOnboardingCard(
                            openedSymbol: selectedSymbol != nil,
                            usedChat: false,
                            onDismiss: { OnboardingStorage.dismissResearchOnboarding() }
                        )
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
                                selectedSymbol = first
                            }
                        }
                    )

                    searchResults(viewModel)

                    if viewModel.query.isEmpty {
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
                    Button {
                        selectedSymbol = item
                    } label: {
                        SymbolSearchRow(item: item)
                    }
                    .buttonStyle(.plain)

                    if index < min(viewModel.results.count, 12) - 1 {
                        AppGroupedDivider()
                    }
                }
            }
        }
    }

    private var examplesSection: some View {
        AppScreenSection(title: "Examples") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(exampleSymbols, id: \.self) { symbol in
                        AppChip(title: symbol) {
                            selectedSymbol = TickerSymbolItem(
                                symbol: symbol,
                                title: nil,
                                assetType: nil,
                                logoURL: nil
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SymbolSearchRow: View {
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
    }
}
