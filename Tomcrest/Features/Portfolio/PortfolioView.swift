import SwiftUI

struct PortfolioView: View {
    @Environment(AuthSession.self) private var auth
    @Binding var selectedTab: AppTab
    @State private var viewModel: PortfolioViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    portfolioContent(viewModel)
                } else {
                    loadingShell
                }
            }
            .background(AppColors.background)
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if viewModel == nil {
                    let model = PortfolioViewModel(auth: auth)
                    viewModel = model
                    await model.loadIfNeeded()
                }
            }
            .onChange(of: selectedTab) { _, tab in
                guard tab == .portfolio, let viewModel else { return }
                switch viewModel.screenState {
                case .schwabNotConnected, .reauthRequired:
                    Task { await viewModel.refresh() }
                default:
                    break
                }
            }
        }
    }

    private var loadingShell: some View {
        ScrollView {
            PortfolioLoadingView()
                .padding(Layout.horizontalPadding)
                .appContentWidth()
        }
    }

    @ViewBuilder
    private func portfolioContent(_ viewModel: PortfolioViewModel) -> some View {
        switch viewModel.screenState {
        case .loading:
            ScrollView {
                PortfolioLoadingView()
                    .padding(Layout.horizontalPadding)
                    .appContentWidth()
            }

        case .schwabNotConnected:
            emptyStateScroll {
                SchwabConnectPrompt(
                    systemImage: "building.columns.circle",
                    title: "Connect Schwab",
                    message: "Link your brokerage to see holdings and your daily brief.",
                    actionTitle: "Open Settings"
                ) {
                    selectedTab = .settings
                }
            }

        case let .reauthRequired(message):
            emptyStateScroll {
                VStack(spacing: Layout.itemSpacing) {
                    SchwabConnectPrompt(
                        systemImage: "exclamationmark.triangle",
                        title: "Schwab needs attention",
                        message: message,
                        actionTitle: "Reconnect Schwab"
                    ) {
                        Task { await viewModel.reconnectSchwab() }
                    }

                    if let error = auth.lastError {
                        AppInlineBanner(message: error, tone: .error)
                    }
                }
            }

        case .empty:
            emptyStateScroll {
                SchwabConnectPrompt(
                    systemImage: "chart.pie",
                    title: "No holdings yet",
                    message: "Your Schwab account is connected but no positions were returned.",
                    actionTitle: "Refresh"
                ) {
                    Task { await viewModel.refresh(fromPull: true) }
                }
            }

        case let .error(message):
            emptyStateScroll {
                AppErrorState(message: message) {
                    Task { await viewModel.refresh() }
                }
            }

        case .content:
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if let snapshot = viewModel.snapshot {
                        PortfolioSnapshotCard(
                            snapshot: snapshot,
                            syncedAtLabel: viewModel.syncedAtLabel
                        )
                    }

                    // One "Today" group — brief + alerts, not two competing AI sections.
                    AppScreenSection(title: "Today") {
                        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                            MorningBriefCard(lead: viewModel.briefLead)

                            if hasAttentionContent(viewModel) {
                                PortfolioAlertsSection(
                                    alerts: viewModel.alerts,
                                    attentionQueue: viewModel.attentionQueue
                                ) { item in
                                    Task { await viewModel.dismissAttentionItem(item) }
                                }
                            }
                        }
                    }

                    if !viewModel.positions.isEmpty {
                        AppScreenSection(
                            title: "Holdings",
                            footnote: "Top 10 by weight"
                        ) {
                            HoldingsSection(positions: viewModel.positions)
                        }
                    }

                    PortfolioChatPanel(viewModel: viewModel)
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, 24)
                .appContentWidth()
            }
            .refreshable {
                await viewModel.refresh(fromPull: true)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // Banner only during background refresh — initial load uses loading shell.
                if viewModel.isRefreshing, viewModel.screenState == .content {
                    AppRefreshBanner(text: "Refreshing portfolio…")
                }
            }
        }
    }

    private func emptyStateScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.vertical, 32)
                .appContentWidth()
        }
    }

    private func hasAttentionContent(_ viewModel: PortfolioViewModel) -> Bool {
        !viewModel.attentionQueue.isEmpty || !viewModel.alerts.isEmpty
    }
}

#Preview {
    AppPreview.environments {
        PortfolioView(selectedTab: .constant(.portfolio))
            .environment(AuthSession())
            .environment(AccountContext())
    }
}
