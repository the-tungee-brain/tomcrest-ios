import SwiftUI

struct TopMoversView: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel: TopMoversViewModel?
    @State private var path: [ResearchRoute] = []

    var body: some View {
        AppRoutedNavigationCanvasStack(path: $path) {
            Group {
                if let viewModel {
                    AppScrollScreen(refresh: { await viewModel.refresh() }) {
                        content(viewModel)
                    }
                } else {
                    AppScrollScreen {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
            }
            .appRootNavigation("Top Movers")
            .navigationDestination(for: ResearchRoute.self) { route in
                switch route {
                case .watchlist:
                    WatchlistHubScreen { symbol in
                        openSymbol(symbol)
                    }
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
                    let vm = TopMoversViewModel(auth: auth)
                    viewModel = vm
                    vm.start()
                }
            }
            .onDisappear {
                viewModel?.stop()
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: TopMoversViewModel) -> some View {
        TopMoversHeader(hasMlMetrics: viewModel.hasMlMetrics)

        MarketRegimeCard(
            regimeId: viewModel.regimeId,
            asOfDate: viewModel.asOfDate,
            updatedAt: viewModel.updatedAt,
            systemStatus: viewModel.systemStatus
        )

        if !viewModel.hasMlMetrics {
            CompositeModelBanner()
        }

        if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            AppInlineBanner(message: error, tone: .error)
        }

        if viewModel.isLoading, viewModel.items.isEmpty {
            ProgressView("Loading rankings…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if viewModel.items.isEmpty {
            AppInlineBanner(
                message: "Rankings are not ready yet. The pipeline may still be running.",
                tone: .neutral
            )
        } else {
            moversList(viewModel)
        }
    }

    @ViewBuilder
    private func moversList(_ viewModel: TopMoversViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RANKED LIST")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Token.textTertiary)
                .tracking(0.6)
                .padding(.horizontal, 4)

            AppGroupedList {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    let symbol = item.symbol.uppercased()
                    TopMoverRow(
                        item: item,
                        companyName: viewModel.companyName(for: symbol),
                        percentileLabel: viewModel.topUniverseLabel(for: item),
                        rowTrend: viewModel.trendDisplayForRow(for: symbol),
                        detailTrend: viewModel.trendDisplayForDetail(symbol: symbol),
                        hasMlMetrics: viewModel.hasMlMetrics,
                        isExpanded: viewModel.expandedSymbol == symbol,
                        inPortfolio: viewModel.isInPortfolio(symbol),
                        segments: viewModel.breakdownSegments(for: symbol),
                        signals: viewModel.keySignals(for: symbol),
                        signalStrength: viewModel.signalStrength(for: symbol),
                        insightHeadline: viewModel.insightHeadline(for: symbol),
                        breakdownLoading: viewModel.breakdownLoadingSymbols.contains(symbol),
                        onToggle: { viewModel.toggleExpanded(symbol) },
                        onResearch: { openSymbol(symbol) }
                    )

                    if index < viewModel.items.count - 1 {
                        AppGroupedDivider()
                    }
                }
            }
        }
    }

    private func openSymbol(_ symbol: String) {
        let item = TickerSymbolItem(
            symbol: symbol.uppercased(),
            title: nil,
            assetType: nil,
            logoURL: nil
        )
        path.append(.symbol(item))
    }
}
