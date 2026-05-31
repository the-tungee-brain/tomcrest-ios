import SwiftUI

struct PortfolioView: View {
    @Environment(AuthSession.self) private var auth
    @Binding var selectedTab: AppTab
    @Binding var settingsFocus: SettingsFocus?
    @State private var viewModel: PortfolioViewModel?
    @State private var researchSymbol: String?

    init(selectedTab: Binding<AppTab>, settingsFocus: Binding<SettingsFocus?> = .constant(nil)) {
        _selectedTab = selectedTab
        _settingsFocus = settingsFocus
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    portfolioContent(viewModel)
                } else {
                    AppScrollScreen {
                        PortfolioLoadingView()
                    }
                }
            }
            .appRootNavigation("Portfolio")
            .navigationDestination(item: $researchSymbol) { symbol in
                SymbolResearchView(symbol: symbol, auth: auth)
            }
            .sheet(isPresented: onboardingWizardBinding) {
                if let viewModel {
                    StrategyOnboardingWizard(
                        catalog: viewModel.strategyCatalog,
                        onComplete: { update in
                            await viewModel.completeStrategyOnboarding(update)
                        },
                        onSaveDraft: { update in
                            await viewModel.saveStrategyOnboardingDraft(update)
                        }
                    )
                }
            }
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

    @ViewBuilder
    private func portfolioContent(_ viewModel: PortfolioViewModel) -> some View {
        switch viewModel.screenState {
        case .loading:
            AppScrollScreen {
                PortfolioLoadingView()
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
            AppScrollScreen(refresh: { await viewModel.refresh(fromPull: true) }) {
                if let snapshot = viewModel.snapshot {
                    PortfolioSnapshotCard(
                        snapshot: snapshot,
                        syncedAtLabel: viewModel.syncedAtLabel
                    )
                }

                PortfolioSectionTabBar(
                    selection: Binding(
                        get: { viewModel.activeSection },
                        set: { viewModel.setActiveSection($0) }
                    ),
                    todayBadge: viewModel.todayBadgeCount,
                    activityBadge: viewModel.activityBadgeCount
                )

                sectionContent(viewModel)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if viewModel.isRefreshing, viewModel.screenState == .content {
                    AppRefreshBanner(text: "Refreshing portfolio…")
                }
            }
        }
    }

    @ViewBuilder
    private func sectionContent(_ viewModel: PortfolioViewModel) -> some View {
        switch viewModel.activeSection {
        case .today:
            AppScreenSection(title: "Today") {
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    if viewModel.showPortfolioOnboarding {
                        PortfolioOnboardingCard(
                            schwabConnected: viewModel.screenState != .schwabNotConnected,
                            hasPositions: !viewModel.positions.isEmpty,
                            hasUsedAssistant: !viewModel.chatMessages.isEmpty,
                            onConnectSchwab: {
                                selectedTab = .settings
                            },
                            onDismiss: {
                                viewModel.dismissPortfolioOnboarding()
                            }
                        )
                    }

                    if viewModel.needsStrategyOnboarding {
                        PortfolioStrategyNudge(
                            onStart: { viewModel.presentOnboardingWizard() },
                            onOpenSettings: {
                                settingsFocus = .strategy
                                selectedTab = .settings
                            }
                        )
                        .overlay(alignment: .topTrailing) {
                            if viewModel.showStrategyNudge || !OnboardingStorage.isStrategyOnboardingDismissed() {
                                Button("Dismiss") {
                                    viewModel.dismissStrategyNudge()
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.secondaryLabel)
                                .padding(8)
                            }
                        }
                    }

                    MorningBriefCard(
                        lead: viewModel.briefLead,
                        changes: viewModel.morningBrief?.changes,
                        macroRegime: viewModel.morningBrief?.macroRegime
                            ?? viewModel.displayBrief?.digest?.macroRegime,
                        digest: viewModel.briefDigest,
                        signals: viewModel.topBriefSignals,
                        isUrgentLead: viewModel.briefIsUrgent,
                        generatedAt: viewModel.morningBrief?.generatedAt,
                        onGoDeeper: {
                            viewModel.runDiversificationAnalysis()
                        },
                        onSymbolTap: { researchSymbol = $0 }
                    )

                    PortfolioAttentionSection(
                        taxItems: viewModel.taxAlertItems,
                        alerts: viewModel.alerts,
                        attentionQueue: viewModel.attentionQueue,
                        suggestedActions: viewModel.portfolioTradeSuggestions,
                        itemCount: viewModel.attentionItemCount,
                        onDismiss: { item in
                            Task { await viewModel.dismissAttentionItem(item) }
                        },
                        onQuickAction: { actionId in
                            viewModel.runQuickAction(actionId)
                        }
                    )

                    if viewModel.showStrategyPlaybook, let strategyId = viewModel.primaryStrategyId {
                        StrategyPlaybookCard(
                            strategyId: strategyId,
                            catalogItem: viewModel.strategyCatalogItem,
                            recommendations: viewModel.strategyRecommendations,
                            isLoading: viewModel.strategyPlaybookLoading,
                            onEditPlaybook: {
                                settingsFocus = .strategy
                                selectedTab = .settings
                            },
                            onRunAction: { action in
                                viewModel.runPlaybookAction(action)
                            },
                            onConnectSchwab: {
                                Task { await viewModel.connectSchwabFromPlaybook() }
                            },
                            onOpenSymbol: { researchSymbol = $0 },
                            isConnectingSchwab: viewModel.isConnectingSchwab,
                            wheelSymbols: StrategyPlaybookHelpers.symbols(from: viewModel.investmentProfile)
                        )
                    }

                    PortfolioAnalysisSection(
                        isLoading: viewModel.portfolioAnalysisLoading,
                        statusText: viewModel.portfolioAnalysisStatus,
                        errorMessage: viewModel.portfolioAnalysisError,
                        analysis: viewModel.structuredAnalysis,
                        precomputed: viewModel.portfolioPrecomputed,
                        onAnalyze: {
                            Task { await viewModel.runPortfolioAnalysis() }
                        },
                        progressiveDisclosure: true
                    )
                }
            }

            PortfolioChatPanel(viewModel: viewModel)

        case .news:
            PortfolioNewsSection(
                items: viewModel.portfolioNews,
                isLoading: viewModel.portfolioNewsLoading,
                onSymbolTap: { researchSymbol = $0 }
            )

        case .holdings:
            if viewModel.positions.isEmpty {
                AppEmptyMessage(message: "No holdings to show.")
            } else {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    PortfolioRiskSection(
                        cashSecuredPutSummary: viewModel.cashSecuredPutSummary,
                        assignmentRiskSummary: viewModel.assignmentRiskSummary,
                        cashBalance: viewModel.snapshot?.cashBalance
                    )

                    AppScreenSection(title: "Holdings", footnote: "Grouped by symbol · tap to research") {
                        PortfolioHoldingsTable(
                            summaries: viewModel.holdingSummaries,
                            alerts: viewModel.alerts,
                            onSymbolTap: { researchSymbol = $0 }
                        )
                    }
                }
            }

        case .activity:
            PortfolioActivitySection(
                orders: viewModel.recentOrders,
                totalOrders: viewModel.totalActivityOrders,
                recentOrderCount: viewModel.recentOrderCount,
                daysBack: viewModel.activityDaysBack,
                symbolFilter: viewModel.activitySymbolFilter,
                activityBySymbol: viewModel.activityBySymbol,
                isLoading: viewModel.recentOrdersLoading,
                errorMessage: viewModel.recentOrdersError,
                onDaysBackChange: { viewModel.setActivityDaysBack($0) },
                onSymbolFilterChange: { viewModel.setActivitySymbolFilter($0) },
                onSymbolTap: { researchSymbol = $0 },
                onRetry: {
                    Task { await viewModel.loadRecentOrdersIfNeeded(force: true) }
                }
            )
        }
    }

    private func emptyStateScroll<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        AppScrollScreen(topPadding: 32, content: content)
    }

    private var onboardingWizardBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showOnboardingWizard ?? false },
            set: { newValue in
                if !newValue {
                    viewModel?.dismissOnboardingWizard()
                } else {
                    viewModel?.presentOnboardingWizard()
                }
            }
        )
    }
}

#Preview {
    AppPreview.environments {
        PortfolioView(selectedTab: .constant(.portfolio))
            .environment(AuthSession())
            .environment(AccountContext())
    }
}
