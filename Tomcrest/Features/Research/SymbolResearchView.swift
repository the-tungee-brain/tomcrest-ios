import SwiftUI

/// Symbol research hub — tab bar + lazy-loaded depth sections (earnings, news, dividends, fundamentals).
struct SymbolResearchView: View {
    @Environment(AccountContext.self) private var account
    @State private var overviewVM: SymbolOverviewViewModel
    @State private var depthVM: SymbolDepthViewModel
    @State private var selectedTab: ResearchTab = .overview

    init(symbol: String, auth: AuthSession) {
        _overviewVM = State(initialValue: SymbolOverviewViewModel(symbol: symbol, auth: auth))
        _depthVM = State(initialValue: SymbolDepthViewModel(symbol: symbol, auth: auth))
    }

    private var availableTabs: [ResearchTab] {
        ResearchTab.tabs(for: overviewVM.bundle?.assetType)
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
            .appTabBarStrip()

            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    tabContent
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .appContentWidth()
            }
            .refreshable {
                await refreshCurrentTab()
            }
        }
        .background(AppColors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(overviewVM.symbol)
                        .font(.headline)
                        .foregroundStyle(AppColors.label)
                    if let companyName {
                        Text(companyName)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                AppToolbarRefreshButton(isRefreshing: isRefreshing) {
                    Task { await refreshCurrentTab() }
                }
            }
        }
        // Banner only for silent background refresh — initial tab load uses AppLoadingState in content.
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsRefreshBanner {
                AppRefreshBanner(text: refreshBannerText)
            }
        }
        .task {
            await overviewVM.loadIfNeeded()
            ensureValidTabSelection()
        }
        .onChange(of: selectedTab) { _, tab in
            Task {
                await depthVM.loadIfNeeded(tab)
                if tab == .earnings {
                    await depthVM.loadEarningsDetail(
                        includeAnalysis: account.hasProFeature(.earningsAi),
                        force: depthVM.selectedHistoryEvent != nil
                    )
                }
            }
        }
        .onChange(of: overviewVM.bundle?.assetType) { _, _ in
            ensureValidTabSelection()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            SymbolOverviewTab(viewModel: overviewVM)
        case .earnings:
            SymbolEarningsTab(viewModel: depthVM)
        case .news:
            SymbolNewsTab(viewModel: depthVM)
        case .dividends:
            SymbolDividendsTab(viewModel: depthVM)
        case .fundamentals:
            SymbolFundamentalsTab(viewModel: depthVM, assetType: overviewVM.bundle?.assetType)
        }
    }

    private var isRefreshing: Bool {
        (selectedTab == .overview && overviewVM.isLoading) || depthVM.loadingTab == selectedTab
    }

    /// Background refresh only — avoid stacking banner on top of in-tab AppLoadingState.
    private var showsRefreshBanner: Bool {
        if selectedTab == .overview {
            return overviewVM.isLoading && overviewVM.bundle != nil
        }
        return false
    }

    private var refreshBannerText: String {
        "Updating overview…"
    }

    private func refreshCurrentTab() async {
        if selectedTab == .overview {
            await overviewVM.reload()
        } else {
            await depthVM.reload(selectedTab)
            if selectedTab == .earnings {
                await depthVM.loadEarningsDetail(
                    includeAnalysis: account.hasProFeature(.earningsAi),
                    force: true
                )
            }
        }
    }

    private func ensureValidTabSelection() {
        let tabs = availableTabs
        if !tabs.contains(selectedTab), let first = tabs.first {
            selectedTab = first
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
    }
}
