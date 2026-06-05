import SwiftUI

private enum MoversSegment: String, CaseIterable {
    case topMovers = "Top Movers"
    case emerging = "Emerging"
}

struct TopMoversView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(TabBarReselectCoordinator.self) private var tabReselect
    @State private var viewModel: TopMoversViewModel?
    @State private var emergingViewModel: EmergingLeadersViewModel?
    @State private var emergingValidationViewModel: EmergingLeadersValidationViewModel?
    @State private var segment: MoversSegment = .topMovers
    @State private var path: [ResearchRoute] = []
    @State private var scrollToTopToken = 0
    @State private var mbAlertsEnabled = true

    var body: some View {
        AppRoutedNavigationCanvasStack(path: $path) {
            Group {
                if let viewModel {
                    AppScrollScreen(
                        refresh: { await viewModel.refresh() },
                        scrollToToken: $scrollToTopToken,
                        scrollAnchor: AppScrollAnchor.top
                    ) {
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
            .toolbar {
                if mbAlertsEnabled {
                    ToolbarItem(placement: .topBarTrailing) {
                        MomentumBreakoutNotificationBell {
                            path.append(.momentumBreakoutAlerts)
                        }
                    }
                }
            }
            .onChange(of: tabReselect.moversReselectCount) { _, _ in
                path = []
                viewModel?.collapseExpanded()
                emergingViewModel?.collapseExpanded()
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
                if let token = auth.accessToken, !token.isEmpty {
                    if let status = try? await MomentumBreakoutAlertService.fetchFeatureStatus(
                        accessToken: token
                    ) {
                        mbAlertsEnabled = status.flags.alertsEnabled
                    }
                }
                if viewModel == nil {
                    let vm = TopMoversViewModel(auth: auth)
                    viewModel = vm
                    vm.start()
                }
            }
            .onChange(of: segment, initial: false) { _, newValue in
                if newValue == .emerging {
                    Task { await ensureEmergingLoaded() }
                } else {
                    emergingViewModel?.stop()
                }
            }
            .onDisappear {
                viewModel?.stop()
                emergingViewModel?.stop()
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: TopMoversViewModel) -> some View {
        Color.clear
            .appTopScrollAnchor()

        Picker("Movers", selection: $segment) {
            ForEach(MoversSegment.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)

        if segment == .emerging {
            if let emergingViewModel,
               let emergingValidationViewModel {
                EmergingLeadersView(
                    viewModel: emergingViewModel,
                    validationViewModel: emergingValidationViewModel,
                    onOpenSymbol: openSymbol
                )
            } else {
                ProgressView("Loading emerging leaders…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .task {
                        await ensureEmergingLoaded()
                    }
            }
        } else {
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
                        rankContext: viewModel.rankContext(for: item),
                        rowConviction: viewModel.convictionForRow(for: item),
                        detailConviction: viewModel.convictionForDetail(
                            symbol: symbol,
                            item: item
                        ),
                        priceTrend: viewModel.priceTrendLabel(for: symbol),
                        sparkline: viewModel.sparklineValues(for: symbol),
                        sparklinePending: !viewModel.hasPatternIntelligence(for: symbol),
                        hasMlMetrics: viewModel.hasMlMetrics,
                        isExpanded: viewModel.expandedSymbol == symbol,
                        inPortfolio: viewModel.isInPortfolio(symbol),
                        segments: viewModel.breakdownSegments(for: symbol),
                        researchInsight: viewModel.researchInsight(for: item, symbol: symbol),
                        portfolioRole: viewModel.portfolioRole(for: item, symbol: symbol),
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

    @MainActor
    private func ensureEmergingLoaded() async {
        if emergingViewModel == nil {
            emergingViewModel = EmergingLeadersViewModel(auth: auth)
        }
        emergingViewModel?.start()

        if emergingValidationViewModel == nil {
            emergingValidationViewModel = EmergingLeadersValidationViewModel(auth: auth)
        }
        if emergingValidationViewModel?.payload == nil,
           emergingValidationViewModel?.isLoading == false {
            await emergingValidationViewModel?.refresh()
        }
    }
}
