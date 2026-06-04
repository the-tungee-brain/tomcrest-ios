import SwiftUI

// MARK: - Today (brief, attention, playbook)

struct PortfolioTodayScreen: View {
    @Environment(AssistantPresenter.self) private var assistant
    @Bindable var viewModel: PortfolioViewModel
    @Binding var selectedTab: AppTab
    @Binding var settingsFocus: SettingsFocus?
    var onGoToPortfolioAnalysis: () -> Void
    var onSymbolTap: (String) -> Void
    var onOpenPosition: (String) -> Void

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                if viewModel.showPortfolioOnboarding {
                    PortfolioOnboardingCard(
                        schwabConnected: viewModel.screenState != .schwabNotConnected,
                        hasPositions: !viewModel.positions.isEmpty,
                        hasUsedAssistant: !viewModel.chatMessages.isEmpty,
                        onConnectSchwab: { selectedTab = .settings },
                        onDismiss: { viewModel.dismissPortfolioOnboarding() }
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
                    onGoDeeper: onGoToPortfolioAnalysis,
                    onSymbolTap: onSymbolTap
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
                        assistant.openPortfolio(
                            prompt: viewModel.runQuickAction(actionId),
                            sendImmediately: true
                        )
                    }
                )

                PortfolioExitAttentionSection(
                    items: viewModel.exitAttentionItems,
                    onSymbolTap: onOpenPosition
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
                            assistant.openPortfolio()
                            viewModel.runPlaybookAction(action)
                        },
                        onConnectSchwab: { Task { await viewModel.connectSchwabFromPlaybook() } },
                        onOpenSymbol: onSymbolTap,
                        isConnectingSchwab: viewModel.isConnectingSchwab,
                        wheelSymbols: StrategyPlaybookHelpers.symbols(from: viewModel.investmentProfile)
                    )
                }
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .appNavigationCanvas()
    }
}

// MARK: - Portfolio analysis + assistant

struct PortfolioAnalysisScreen: View {
    @Environment(AssistantPresenter.self) private var assistant
    @Bindable var viewModel: PortfolioViewModel

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                PortfolioAnalysisSection(
                    isLoading: viewModel.portfolioAnalysisLoading,
                    statusText: viewModel.portfolioAnalysisStatus,
                    errorMessage: viewModel.portfolioAnalysisError,
                    analysis: viewModel.structuredAnalysis,
                    precomputed: viewModel.portfolioPrecomputed,
                    onAnalyze: { Task { await viewModel.runPortfolioAnalysis() } },
                    progressiveDisclosure: true
                )

                AssistantLauncherRow(
                    title: "Ask Tomcrest",
                    subtitle: "Portfolio assistant — holdings, risk, and cash"
                ) {
                    assistant.openPortfolio()
                }
            }
        }
        .navigationTitle("Portfolio analysis")
        .navigationBarTitleDisplayMode(.large)
        .appNavigationCanvas()
    }
}

// MARK: - Full holdings + options risk

struct PortfolioHoldingsScreen: View {
    @Bindable var viewModel: PortfolioViewModel
    var onSymbolTap: (String) -> Void

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                if viewModel.positions.isEmpty {
                    AppEmptyMessage(message: "No holdings to show.")
                } else {
                    PortfolioRiskSection(
                        cashSecuredPutSummary: viewModel.cashSecuredPutSummary,
                        assignmentRiskSummary: viewModel.assignmentRiskSummary,
                        cashBalance: viewModel.snapshot?.cashBalance
                    )

                    AppScreenSection(title: "All positions", footnote: "Grouped by symbol") {
                        PortfolioHoldingsTable(
                            summaries: viewModel.holdingSummaries,
                            alerts: viewModel.alerts,
                            onSymbolTap: onSymbolTap
                        )
                    }
                }
            }
        }
        .navigationTitle("Holdings")
        .navigationBarTitleDisplayMode(.large)
        .appNavigationCanvas()
    }
}

// MARK: - News

struct PortfolioNewsScreen: View {
    @Bindable var viewModel: PortfolioViewModel
    var onSymbolTap: (String) -> Void

    var body: some View {
        AppScrollScreen {
            PortfolioNewsSection(
                items: viewModel.portfolioNews,
                isLoading: viewModel.portfolioNewsLoading,
                onSymbolTap: onSymbolTap
            )
        }
        .navigationTitle("Headlines")
        .navigationBarTitleDisplayMode(.large)
        .appNavigationCanvas()
        .task {
            await viewModel.loadPortfolioNewsIfNeeded()
        }
    }
}

// MARK: - Activity

struct PortfolioActivityScreen: View {
    @Bindable var viewModel: PortfolioViewModel
    var onSymbolTap: (String) -> Void

    var body: some View {
        AppScrollScreen {
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
                onSymbolTap: onSymbolTap,
                onRetry: { Task { await viewModel.loadRecentOrdersIfNeeded(force: true) } }
            )
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .appNavigationCanvas()
        .task {
            await viewModel.loadRecentOrdersIfNeeded()
        }
    }
}
