import SwiftUI

struct PortfolioView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(AssistantPresenter.self) private var assistant
    @Binding var selectedTab: AppTab
    @Binding var settingsFocus: SettingsFocus?
    @State private var viewModel: PortfolioViewModel?
    @State private var researchSymbol: String?
    @State private var path: [PortfolioDestination] = []

    init(selectedTab: Binding<AppTab>, settingsFocus: Binding<SettingsFocus?> = .constant(nil)) {
        _selectedTab = selectedTab
        _settingsFocus = settingsFocus
    }

    var body: some View {
        AppRoutedNavigationCanvasStack(path: $path) {
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
            .navigationDestination(for: PortfolioDestination.self) { destination in
                if let viewModel {
                    portfolioDestination(destination, viewModel: viewModel)
                }
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
            .overlay(alignment: .bottomTrailing) {
                if let viewModel, viewModel.screenState == .content {
                    FloatingAssistantButton {
                        assistant.openPortfolio()
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
                }
            }
            .sheet(isPresented: portfolioAssistantPresented) {
                if let viewModel {
                    PortfolioAssistantSheet(viewModel: viewModel)
                }
            }
        }
    }

    private var portfolioAssistantPresented: Binding<Bool> {
        Binding(
            get: { assistant.isPortfolioPresented },
            set: { if !$0 { assistant.dismiss() } }
        )
    }

    // MARK: - Dashboard (minimal main screen)

    @ViewBuilder
    private func portfolioContent(_ viewModel: PortfolioViewModel) -> some View {
        switch viewModel.screenState {
        case .loading:
            AppScrollScreen { PortfolioLoadingView() }

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
            portfolioDashboard(viewModel)
        }
    }

    @ViewBuilder
    private func portfolioDashboard(_ viewModel: PortfolioViewModel) -> some View {
        AppScrollScreen(refresh: { await viewModel.refresh(fromPull: true) }) {
            if let snapshot = viewModel.snapshot {
                PortfolioHeroSummary(
                    liquidationValue: snapshot.liquidationValue,
                    totalDayProfitLoss: viewModel.totalDayProfitLoss,
                    totalOpenProfitLoss: snapshot.totalOpenProfitLoss ?? 0,
                    openProfitLossPct: snapshot.openProfitLossPct,
                    cashBalance: snapshot.cashBalance,
                    syncedAtLabel: viewModel.syncedAtLabel
                )
            }

            if viewModel.needsStrategyOnboarding, viewModel.showStrategyNudge {
                PortfolioStrategyNudge(
                    onStart: { viewModel.presentOnboardingWizard() },
                    onOpenSettings: {
                        settingsFocus = .strategy
                        selectedTab = .settings
                    }
                )
            }

            NavigationLink(value: PortfolioDestination.today) {
                PortfolioBriefPreview(
                    lead: viewModel.briefLead,
                    isUrgent: viewModel.briefIsUrgent,
                    attentionCount: viewModel.attentionItemCount
                )
            }
            .buttonStyle(.plain)

            exploreSection(viewModel)

            holdingsPreviewSection(viewModel)
        }
    }

    @ViewBuilder
    private func exploreSection(_ viewModel: PortfolioViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Explore")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                portfolioLink(.today, viewModel: viewModel) {
                    PortfolioQuickLinkRow(
                        icon: "sun.max.fill",
                        title: "Today's briefing",
                        subtitle: "Morning brief, alerts & playbook",
                        badge: viewModel.todayBadgeCount
                    )
                }
                Divider().overlay(AppColors.separator).padding(.leading, 58)
                portfolioLink(.portfolioAnalysis, viewModel: viewModel) {
                    PortfolioQuickLinkRow(
                        icon: "chart.bar.doc.horizontal.fill",
                        title: "Portfolio analysis",
                        subtitle: "Diversification review, cash map & action plan"
                    )
                }
                Divider().overlay(AppColors.separator).padding(.leading, 58)
                portfolioLink(.holdings, viewModel: viewModel) {
                    PortfolioQuickLinkRow(
                        icon: "chart.pie.fill",
                        title: "Holdings & risk",
                        subtitle: "\(viewModel.snapshot?.symbolCount ?? 0) symbols · sort & filter"
                    )
                }
                Divider().overlay(AppColors.separator).padding(.leading, 58)
                portfolioLink(.news, viewModel: viewModel) {
                    PortfolioQuickLinkRow(
                        icon: "newspaper.fill",
                        iconTint: AppColors.secondaryLabel,
                        title: "Headlines",
                        subtitle: "News from your largest positions"
                    )
                }
                Divider().overlay(AppColors.separator).padding(.leading, 58)
                portfolioLink(.activity, viewModel: viewModel) {
                    PortfolioQuickLinkRow(
                        icon: "arrow.left.arrow.right",
                        iconTint: AppColors.secondaryLabel,
                        title: "Activity",
                        subtitle: "Recent trades",
                        badge: viewModel.activityBadgeCount
                    )
                }
            }
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.panelBorder, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func holdingsPreviewSection(_ viewModel: PortfolioViewModel) -> some View {
        let top = viewModel.topHoldings(limit: 6)
        if !top.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Top holdings")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)
                    Spacer()
                    if viewModel.holdingSummaries.count > top.count {
                        NavigationLink(value: PortfolioDestination.holdings) {
                            Text("View all")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.accentHighlight)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)

                PortfolioCompactHoldingsList(summaries: top) { symbol in
                    researchSymbol = symbol
                }
            }
        }
    }

    @ViewBuilder
    private func portfolioLink<Label: View>(
        _ destination: PortfolioDestination,
        viewModel: PortfolioViewModel,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink(value: destination, label: label)
            .buttonStyle(.plain)
    }

    @ViewBuilder
    private func portfolioDestination(
        _ destination: PortfolioDestination,
        viewModel: PortfolioViewModel
    ) -> some View {
        Group {
            switch destination {
            case .today:
                PortfolioTodayScreen(
                    viewModel: viewModel,
                    selectedTab: $selectedTab,
                    settingsFocus: $settingsFocus,
                    onSymbolTap: { researchSymbol = $0 }
                )
            case .portfolioAnalysis:
                PortfolioAnalysisScreen(viewModel: viewModel)
            case .holdings:
                PortfolioHoldingsScreen(viewModel: viewModel, onSymbolTap: { researchSymbol = $0 })
            case .news:
                PortfolioNewsScreen(viewModel: viewModel, onSymbolTap: { researchSymbol = $0 })
            case .activity:
                PortfolioActivityScreen(viewModel: viewModel, onSymbolTap: { researchSymbol = $0 })
            }
        }
        .appPushedScreenCanvas()
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
            .environment(AssistantPresenter())
    }
}
