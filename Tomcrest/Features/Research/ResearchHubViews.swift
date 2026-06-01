import SwiftUI

// MARK: - Overview explore links

struct ResearchExploreLinks: View {
    let symbol: String
    let assetType: String?
    let availableTabs: [ResearchTab]
    @Binding var selectedTab: ResearchTab
    var onOpenMore: (ResearchMoreDestination) -> Void

    private struct Row: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let systemImage: String
        let tab: ResearchTab?
        let more: ResearchMoreDestination?
    }

    private var rows: [Row] {
        var items: [Row] = []

        if availableTabs.contains(.analysis) {
            items.append(
                Row(
                    id: "analysis",
                    title: "Analysis",
                    subtitle: "AI insights, 5D trend, and business context",
                    systemImage: "sparkles",
                    tab: .analysis,
                    more: nil
                )
            )
        }

        if availableTabs.contains(.metrics) {
            items.append(
                Row(
                    id: "metrics",
                    title: ResearchTab.metrics.metricsLabel(for: assetType),
                    subtitle: "Valuation, growth, and analyst views",
                    systemImage: "gauge.with.dots.needle.67percent",
                    tab: .metrics,
                    more: nil
                )
            )
        }

        if availableTabs.contains(.news) {
            items.append(
                Row(
                    id: "news",
                    title: "News",
                    subtitle: "Headlines and company releases",
                    systemImage: "newspaper",
                    tab: .news,
                    more: nil
                )
            )
        }

        if availableTabs.contains(.financials) {
            items.append(
                Row(
                    id: "financials",
                    title: "Financials",
                    subtitle: "Statements, ratios, and SEC filings",
                    systemImage: "doc.text",
                    tab: .financials,
                    more: nil
                )
            )
        }

        if availableTabs.contains(.more) {
            for destination in ResearchMoreDestination.destinations(for: assetType, includesOptions: true) {
                items.append(
                    Row(
                        id: destination.rawValue,
                        title: destination.label,
                        subtitle: destination.subtitle,
                        systemImage: destination.systemImage,
                        tab: .more,
                        more: destination
                    )
                )
            }
        }

        return items
    }

    var body: some View {
        if !rows.isEmpty {
            AppScreenSection(title: "Go deeper") {
                AppGroupedList {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        Button {
                            navigate(to: row)
                        } label: {
                            ResearchHubLinkRow(
                                title: row.title,
                                subtitle: row.subtitle,
                                systemImage: row.systemImage
                            )
                        }
                        .buttonStyle(.plain)

                        if index < rows.count - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }

    private func navigate(to row: Row) {
        if let tab = row.tab {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        }
        if let more = row.more {
            onOpenMore(more)
        }
    }
}

struct ResearchHubLinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.accentHighlight)
                .frame(width: 32, height: 32)
                .background(AppColors.accentMuted.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
    }
}

// MARK: - Analysis hub

struct SymbolAnalysisHubTab: View {
    @Environment(AccountContext.self) private var account
    @Environment(AssistantPresenter.self) private var assistant
    @Bindable var overviewVM: SymbolOverviewViewModel
    @Bindable var depthVM: SymbolDepthViewModel
    let bundle: ResearchOverviewBundle?

    var body: some View {
        ResearchDepthTabShell(tab: .analysis, viewModel: depthVM) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                if let bundle, !bundle.intelligence.signals.isEmpty {
                    SymbolIntelligenceOverviewPanel(signals: bundle.intelligence.signals) { prompt in
                        assistant.openSymbol(overviewVM.symbol, prompt: prompt, sendImmediately: true)
                    }
                }

                BigPictureSection(
                    summary: bundle?.summary,
                    isLoading: overviewVM.isBigPictureLoading,
                    errorMessage: overviewVM.bigPictureError,
                    onRefresh: {
                        Task { await overviewVM.refreshBigPicture() }
                    }
                )

                SymbolPatternPredictionContent(viewModel: depthVM)

                SymbolBusinessContent(viewModel: depthVM)
            }
        }
    }
}

// MARK: - Metrics hub

struct SymbolMetricsHubTab: View {
    let assetType: String?

    @Bindable var depthVM: SymbolDepthViewModel

    var body: some View {
        SymbolFundamentalsTab(viewModel: depthVM, assetType: assetType)
    }
}

// MARK: - More hub

struct ResearchMoreTab: View {
    let symbol: String
    let assetType: String?
    let includesOptions: Bool
    @Binding var destination: ResearchMoreDestination?
    @Bindable var overviewVM: SymbolOverviewViewModel
    @Bindable var depthVM: SymbolDepthViewModel
    @Bindable var positionVM: SymbolPositionViewModel
    @Binding var backtestExploreSection: BacktestExploreSection?
    let primaryStrategy: String?
    var onAssistantPrompt: (String) -> Void

    var body: some View {
        if let destination {
            moreDetail(destination)
        } else {
            moreMenu
        }
    }

    private var moreMenu: some View {
        AppScreenSection(title: "More") {
            AppGroupedList {
                ForEach(Array(availableDestinations.enumerated()), id: \.element.id) { index, item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            destination = item
                        }
                    } label: {
                        ResearchHubLinkRow(
                            title: item.label,
                            subtitle: item.subtitle,
                            systemImage: item.systemImage
                        )
                    }
                    .buttonStyle(.plain)

                    if index < availableDestinations.count - 1 {
                        AppGroupedDivider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func moreDetail(_ destination: ResearchMoreDestination) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.destination = nil
                    backtestExploreSection = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text("More")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppColors.accentHighlight)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)

            switch destination {
            case .portfolio:
                SymbolPortfolioHubTab(
                    positionVM: positionVM,
                    depthVM: depthVM,
                    symbol: symbol,
                    includesOptions: includesOptions,
                    onAssistantPrompt: onAssistantPrompt
                )
            case .income:
                SymbolIncomeHubTab(viewModel: depthVM)
            case .tools:
                SymbolBacktestTab(
                    exploreSection: $backtestExploreSection,
                    viewModel: depthVM,
                    primaryStrategy: primaryStrategy,
                    marketSharePrice: overviewVM.bundle?.snapshot.price
                )
            case .composition:
                SymbolCompositionTab(viewModel: depthVM)
            }
        }
    }

    private var availableDestinations: [ResearchMoreDestination] {
        ResearchMoreDestination.destinations(for: assetType, includesOptions: includesOptions)
    }
}

// MARK: - Portfolio hub (positions + options)

struct SymbolPortfolioHubTab: View {
    @Bindable var positionVM: SymbolPositionViewModel
    @Bindable var depthVM: SymbolDepthViewModel
    let symbol: String
    let includesOptions: Bool
    var onAssistantPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            SymbolPositionTab(viewModel: positionVM, showsOptionsPrompt: false) { prompt in
                onAssistantPrompt(prompt)
            }

            if includesOptions {
                SymbolOptionsTab(
                    viewModel: depthVM,
                    symbolPositions: positionVM.positions,
                    assignmentRiskSummary: OptionsRiskHelpers.filterAssignmentRisk(
                        positionVM.assignmentRiskSummary,
                        symbol: symbol
                    ),
                    onAnalyze: onAssistantPrompt
                )
            }
        }
    }
}

// MARK: - Income hub (dividends + earnings)

struct SymbolIncomeHubTab: View {
    @Bindable var viewModel: SymbolDepthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            SymbolDividendsTab(viewModel: viewModel)
            SymbolEarningsTab(viewModel: viewModel)
        }
    }
}
