import SwiftUI
import Charts

// MARK: - Overview tab (quote, performance, signals, chat)

struct SymbolOverviewTab: View {
    @Environment(AuthSession.self) private var auth
    @Bindable var viewModel: SymbolOverviewViewModel
    @Bindable var positionViewModel: SymbolPositionViewModel
    let bundle: ResearchOverviewBundle?
    let availableTabs: [ResearchTab]
    let symbolItem: TickerSymbolItem
    var onOpenHub: (SymbolResearchDestination) -> Void
    var onQuickAction: (String) -> Void = { _ in }

    var body: some View {
        Group {
            if viewModel.isLoading, bundle == nil {
                ResearchOverviewLoadingView()
            } else if let error = viewModel.errorMessage, bundle == nil {
                AppErrorState(message: error) {
                    Task { await viewModel.reload() }
                }
            } else if let bundle {
                overviewSections(bundle)
            }
        }
        .task(id: bundle?.symbol) {
            guard bundle != nil else { return }
            await positionViewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var isEtfLike: Bool {
        let normalized = bundle?.assetType?.uppercased() ?? ""
        return normalized == "ETF" || normalized == "MUTUAL_FUND" || normalized == "INDEX"
    }

    @ViewBuilder
    private func overviewSections(_ bundle: ResearchOverviewBundle) -> some View {
        SymbolQuoteHeroCard(bundle: bundle)

        if !isEtfLike {
            TradeDecisionPanelView(
                symbol: viewModel.symbol,
                accessToken: auth.accessToken
            )
        }

        if positionViewModel.hasPosition, !positionViewModel.symbolAlerts.isEmpty {
            SymbolAlertStrip(
                symbol: viewModel.symbol,
                alerts: positionViewModel.symbolAlerts
            ) { alert in
                onQuickAction(
                    IntelligenceHelpers.quickActionMessage(
                        actionId: IntelligenceHelpers.alertToQuickActionId(alert),
                        symbol: viewModel.symbol
                    )
                )
            }
        }

        ResearchStockChartSection(symbol: bundle.symbol, viewModel: viewModel)

        AppScreenSection(title: "Performance") {
            SymbolPerformanceCard(performance: bundle.performance)
        }

        ResearchExploreLinks(
            symbolItem: symbolItem,
            assetType: bundle.assetType,
            availableTabs: availableTabs,
            onOpenHub: onOpenHub
        )
    }
}

// MARK: - Position tab (web SymbolPositionContent)

struct SymbolPositionTab: View {
    @Bindable var viewModel: SymbolPositionViewModel
    var showsOptionsPrompt = true
    var onQuickAction: (String) -> Void = { _ in }

    var body: some View {
        Group {
            if viewModel.isLoading, !viewModel.hasPosition, viewModel.schwabConnected != false {
                AppLoadingState(message: "Loading your \(viewModel.symbol) position…")
            } else if viewModel.schwabConnected == false {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "building.columns.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)

                    Text("Connect Schwab")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.label)

                    Text("Link your brokerage to see positions and trade activity for \(viewModel.symbol).")
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .appPanel(subtle: true)
            } else if let error = viewModel.loadError, !viewModel.hasPosition {
                AppErrorState(message: error) {
                    Task { await viewModel.loadIfNeeded(force: true) }
                }
            } else if !viewModel.hasPosition {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "briefcase")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)

                    Text("No Schwab position")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.label)

                    Text(
                        "You are not holding \(viewModel.symbol) in your linked Schwab account. " +
                            "Use Overview for company research."
                    )
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .appPanel(subtle: true)
            } else {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if !viewModel.taxAlertItems.isEmpty {
                        SymbolTaxWashSaleStrip(items: viewModel.taxAlertItems) { item in
                            onQuickAction(
                                IntelligenceHelpers.quickActionMessage(
                                    actionId: item.actionId,
                                    symbol: viewModel.symbol
                                )
                            )
                        }
                    }

                    if !viewModel.symbolAlerts.isEmpty {
                        SymbolAlertStrip(
                            symbol: viewModel.symbol,
                            alerts: viewModel.symbolAlerts
                        ) { alert in
                            onQuickAction(
                                IntelligenceHelpers.quickActionMessage(
                                    actionId: IntelligenceHelpers.alertToQuickActionId(alert),
                                    symbol: viewModel.symbol
                                )
                            )
                        }
                    }

                    SymbolPositionLegsSection(
                        symbol: viewModel.symbol,
                        positions: viewModel.positions
                    )

                    if showsOptionsPrompt, viewModel.hasOptionPositions {
                        OptionsTabPrompt(symbol: viewModel.symbol) {
                            onQuickAction("__open_portfolio_options__")
                        }
                    }

                    SymbolAnalysisSection(
                        symbol: viewModel.symbol,
                        isLoading: viewModel.symbolAnalysisLoading,
                        statusText: viewModel.symbolAnalysisStatus,
                        errorMessage: viewModel.symbolAnalysisError,
                        analysis: viewModel.structuredAnalysis,
                        precomputed: viewModel.symbolPrecomputed,
                        onAnalyze: {
                            Task { await viewModel.runSymbolAnalysis() }
                        },
                        onAskFollowUp: onQuickAction
                    )

                    SymbolRecentActivitySection(
                        symbol: viewModel.symbol,
                        orders: viewModel.recentOrders,
                        suggestedActions: viewModel.tradeSuggestedActions,
                        isLoading: viewModel.recentOrdersLoading,
                        errorMessage: viewModel.recentOrdersError,
                        onRetry: {
                            Task { await viewModel.loadRecentOrdersIfNeeded(force: true) }
                        },
                        onSuggestedAction: { action in
                            onQuickAction(
                                IntelligenceHelpers.quickActionMessage(
                                    actionId: action.action,
                                    symbol: viewModel.symbol
                                )
                            )
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Earnings tab

struct SymbolEarningsTab: View {
    @Environment(AccountContext.self) private var account
    let viewModel: SymbolDepthViewModel

    var body: some View {
        ResearchDepthTabShell(tab: .more, viewModel: viewModel) {
            if let message = viewModel.incomeEarningsError {
                AppInlineBanner(message: message, tone: .error)
            } else if let earnings = viewModel.earnings {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if let upcoming = earnings.upcoming {
                        AppScreenSection(
                            title: "Upcoming",
                            footnote: EarningsFormatters.formatReportDate(upcoming.reportDate)
                        ) {
                            EarningsEventCard(event: upcoming)
                        }
                    }

                    if !earnings.history.isEmpty {
                        AppScreenSection(title: "History") {
                            EarningsQuarterPicker(
                                events: earnings.history,
                                selection: viewModel.selectedHistoryEvent
                            ) { event in
                                Task {
                                    await viewModel.selectHistoryEvent(event)
                                }
                            }

                            if let selected = viewModel.selectedHistoryEvent {
                                if EarningsSelection.shouldLoadDetail(for: selected) {
                                    EarningsDetailSection(
                                        previewEvent: selected,
                                        detail: viewModel.earningsDetail,
                                        isLoading: viewModel.earningsDetailLoading,
                                        error: viewModel.earningsDetailError,
                                        earningsAiAllowed: account.hasProFeature(.earningsAi),
                                        analysisRequested: viewModel.earningsAnalysisRequested,
                                        onRequestAnalysis: {
                                            Task { await viewModel.requestEarningsAnalysis() }
                                        }
                                    )
                                } else {
                                    AppEmptyMessage(
                                        message: "This period has estimates only. Detail will appear after earnings are reported.",
                                        systemImage: "calendar"
                                    )
                                }
                            }
                        }
                    } else if earnings.upcoming == nil {
                        AppEmptyMessage(
                            message: "No earnings history is available for this symbol yet.",
                            systemImage: "chart.bar.doc.horizontal"
                        )
                    }
                }
                .task(id: viewModel.selectedHistoryEvent?.id) {
                    guard let event = viewModel.selectedHistoryEvent,
                          EarningsSelection.shouldLoadDetail(for: event) else { return }
                    await viewModel.loadEarningsDetail(includeAnalysis: false)
                }
            }
        }
    }
}

private struct EarningsEventCard: View {
    let event: EarningsEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(event.fiscalPeriod)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                Spacer()
                if let beat = event.beatLabel {
                    AppStatusPill(
                        label: EarningsFormatters.beatLabel(beat),
                        tone: earningsBeatTone(beat)
                    )
                }
            }

            Text(EarningsFormatters.formatReportDate(event.reportDate))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)

            AppMetricStrip(items: EarningsFormatters.metricItems(for: event))
        }
        .appPanel(subtle: true)
    }
}

/// History detail — beat + report date accessory, metrics strip only (picker shows quarter).
private struct EarningsQuarterMetrics: View {
    let event: EarningsEvent

    var body: some View {
        AppMetricPanel(items: EarningsFormatters.metricItems(for: event)) {
            HStack(alignment: .center, spacing: 8) {
                if let beat = event.beatLabel {
                    AppStatusPill(
                        label: EarningsFormatters.beatLabel(beat),
                        tone: earningsBeatTone(beat)
                    )
                }
                Spacer(minLength: 0)
                Text(EarningsFormatters.formatReportDate(event.reportDate))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
    }
}

private func earningsBeatTone(_ label: String) -> AppStatusPill.Tone {
    switch label {
    case "beat": .success
    case "miss": .error
    default: .neutral
    }
}

private struct EarningsQuarterPicker: View {
    let events: [EarningsEvent]
    let selection: EarningsEvent?
    let onSelect: (EarningsEvent) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(events) { event in
                    AppChip(
                        title: event.fiscalPeriod,
                        isSelected: selection?.id == event.id
                    ) {
                        onSelect(event)
                    }
                }
            }
        }
    }
}

private struct EarningsDetailSection: View {
    let previewEvent: EarningsEvent
    let detail: EarningsDetailResponse?
    let isLoading: Bool
    let error: String?
    let earningsAiAllowed: Bool
    let analysisRequested: Bool
    let onRequestAnalysis: () -> Void

    @State private var aiExpanded = false
    @State private var analysisDetailsExpanded = false
    @State private var releasesExpanded = false
    @State private var newsExpanded = false
    @State private var transcriptExpanded = false

    private var event: EarningsEvent {
        detail?.event ?? previewEvent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            // Quarter chip already shows period — metrics only, no duplicate title card.
            EarningsQuarterMetrics(event: event)

            if let error, earningsAiAllowed {
                AppInlineBanner(message: error, tone: .error)
            }

            if earningsAiAllowed {
                AppDisclosureSection(title: "Analysis", isExpanded: $aiExpanded) {
                    earningsAnalysisContent
                }
            } else {
                proUpsellBanner
            }

            if let releases = detail?.officialReleases, !releases.isEmpty {
                AppDisclosureSection(
                    title: "Official releases",
                    footnote: "\(releases.count)",
                    isExpanded: $releasesExpanded
                ) {
                    earningsNewsList(releases)
                }
            }

            if let news = detail?.relatedNews, !news.isEmpty {
                AppDisclosureSection(
                    title: "Related news",
                    footnote: "\(news.count)",
                    isExpanded: $newsExpanded
                ) {
                    earningsNewsList(news)
                }
            }

            if let transcript = detail?.transcript, !transcript.isEmpty {
                AppDisclosureSection(
                    title: "Call transcript",
                    footnote: "\(transcript.count) segments",
                    isExpanded: $transcriptExpanded
                ) {
                    transcriptContent(transcript)
                }
            }
        }
    }

    private var proUpsellBanner: some View {
        AppInlineBanner(
            message: "Upgrade to Pro for AI earnings summaries and investor takeaways.",
            tone: .neutral
        )
    }

    private var isAnalysisLoading: Bool {
        analysisRequested && isLoading && detail?.analysis == nil
    }

    @ViewBuilder
    private var earningsAnalysisContent: some View {
        if !analysisRequested {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "Summarize this quarter — highlights, surprises, guidance, and investor takeaway."
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(3)

                Button("Run AI analysis", action: onRequestAnalysis)
                    .buttonStyle(AppCompactButtonStyle())
                    .disabled(isLoading && detail == nil)
            }
        } else if isAnalysisLoading {
            earningsAnalysisSkeleton
        } else if let analysis = detail?.analysis {
            earningsAnalysisBlock(analysis)
        } else if !isLoading, error == nil {
            Text("AI analysis is not available for this quarter.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
    }

    private var earningsAnalysisSkeleton: some View {
        HStack(spacing: 10) {
            ProgressView().tint(AppColors.accent)
            Text("Generating AI analysis…")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func earningsAnalysisBlock(_ analysis: EarningsAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(analysis.headline)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                Text(analysis.summary)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(3)
            }

            earningsTextBlock(title: "Takeaway", body: analysis.investorTakeaway, emphasized: true)

            // Long-form sections collapsed — headline + takeaway are enough for most scans.
            AppDisclosureSection(title: "More detail", isExpanded: $analysisDetailsExpanded) {
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    earningsTextBlock(title: "Context", body: analysis.context)
                    earningsBulletBlock(title: "Highlights", items: analysis.keyHighlights)
                    earningsTextBlock(title: "Guidance", body: analysis.guidanceAndOutlook)
                    earningsTextBlock(title: "Surprises", body: analysis.whatSurprised)
                }
            }
        }
    }

    @ViewBuilder
    private func earningsTextBlock(title: String, body: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(body)
                .font(emphasized ? AppTypography.bodySecondary.weight(.medium) : AppTypography.bodySecondary)
                .foregroundStyle(AppColors.label)
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private func earningsBulletBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text(item)
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.label)
                }
            }
        }
    }

    @ViewBuilder
    private func earningsNewsList(_ items: [NewsHeadline]) -> some View {
        AppGroupedList {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                AppNewsHeadlineRow(item: item)
                if index < items.count - 1 {
                    AppGroupedDivider()
                }
            }
        }
    }

    @ViewBuilder
    private func transcriptContent(_ segments: [TranscriptSegment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.speaker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                    Text(segment.text)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.label)
                        .lineSpacing(2)
                }
            }
        }
    }
}

// MARK: - News tab (web ResearchNewsHub parity)

struct SymbolNewsTab: View {
    @Environment(AccountContext.self) private var account
    let viewModel: SymbolDepthViewModel

    @State private var scope: NewsFeedScope = .all
    @State private var analysisDetailExpanded = false

    private var officialItems: [NewsHeadline] {
        viewModel.news?.items ?? []
    }

    private var coverageItems: [EnrichedNewsItem] {
        viewModel.companyNews?.items ?? []
    }

    var body: some View {
        ResearchDepthTabShell(tab: .news, viewModel: viewModel) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                NewsFeedScopeBar(
                    scope: $scope,
                    officialCount: officialItems.count,
                    coverageCount: coverageItems.count
                )

                if let error = viewModel.tabErrors[.news] {
                    AppInlineBanner(message: error, tone: .error)
                }

                switch scope {
                case .all:
                    allScopeContent
                case .coverage:
                    coverageScopeContent
                case .official:
                    officialScopeContent
                }
            }
        }
    }

    @ViewBuilder
    private var allScopeContent: some View {
        aiBriefSection

        if !coverageItems.isEmpty {
            AppScreenSection(
                title: "Market coverage",
                footnote: viewModel.companyNews?.hasAiAnalysis == true ? "AI summaries" : nil
            ) {
                NewsHeadlinesGroupedList(
                    enrichedItems: coverageItems,
                    showSentiment: viewModel.companyNews?.hasAiAnalysis == true,
                    limit: NewsFeedPreview.limit
                )
                if coverageItems.count > NewsFeedPreview.limit {
                    NewsViewAllButton(label: "View all \(coverageItems.count) stories") {
                        scope = .coverage
                    }
                }
            }
        }

        AppScreenSection(title: "From the company") {
            if officialItems.isEmpty {
                officialEmptyHint
            } else {
                PressReleasesGroupedList(items: officialItems, limit: NewsFeedPreview.limit)
                if officialItems.count > NewsFeedPreview.limit {
                    NewsViewAllButton(label: "View all \(officialItems.count) official releases") {
                        scope = .official
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var coverageScopeContent: some View {
        aiBriefSection

        if coverageItems.isEmpty {
            AppEmptyMessage(message: "No market coverage headlines yet.")
        } else {
            AppScreenSection(
                title: "Headlines",
                footnote: "\(coverageItems.count) stories"
            ) {
                NewsHeadlinesGroupedList(
                    enrichedItems: coverageItems,
                    showSentiment: viewModel.companyNews?.hasAiAnalysis == true
                )
            }
        }

        if let analytics = viewModel.companyNews, analytics.hasAiAnalysis {
            AppDisclosureSection(title: "Analysis detail", isExpanded: $analysisDetailExpanded) {
                NewsAnalysisDetailSections(analytics: analytics)
            }
        }
    }

    @ViewBuilder
    private var officialScopeContent: some View {
        AppScreenSection(title: "Press releases") {
            if officialItems.isEmpty {
                officialEmptyHint
            } else {
                PressReleasesGroupedList(items: officialItems)
            }
        }
    }

    @ViewBuilder
    private var aiBriefSection: some View {
        AppScreenSection(title: "AI news brief") {
            if account.hasProFeature(.newsAi) {
                if viewModel.companyNewsAnalyzing, viewModel.companyNews?.hasAiAnalysis != true {
                    HStack(spacing: 10) {
                        ProgressView().tint(AppColors.accent)
                        Text("Analyzing news…")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(.vertical, 4)
                } else if let analytics = viewModel.companyNews, analytics.hasAiAnalysis {
                    NewsAiBriefCard(analytics: analytics)
                } else {
                    NewsAnalyzePromptCard(
                        storyCount: coverageItems.count,
                        isAnalyzing: viewModel.companyNewsAnalyzing
                    ) {
                        Task { await viewModel.analyzeCompanyNews() }
                    }
                }
            } else {
                AppInlineBanner(
                    message: "Upgrade to Pro for AI news sentiment and synthesized briefs.",
                    tone: .neutral
                )
            }
        }
    }

    private var officialEmptyHint: some View {
        AppEmptyMessage(
            message: "No press releases in the last 90 days. Official IR announcements appear here.",
            systemImage: "doc.text"
        )
    }
}

// MARK: - Dividends tab

struct SymbolDividendsTab: View {
    @Bindable var viewModel: SymbolDepthViewModel

    @State private var annualExpanded = false

    var body: some View {
        ResearchDepthTabShell(tab: .more, viewModel: viewModel) {
            if let message = viewModel.incomeDividendsError {
                AppInlineBanner(message: message, tone: .error)
            } else if let context = viewModel.dividends {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    // Recent payments first — the tab’s primary read; summary stays compact below.
                    if !context.recentPayments.isEmpty {
                        AppScreenSection(title: "Recent payments") {
                            AppGroupedList {
                                ForEach(Array(context.recentPayments.prefix(8).enumerated()), id: \.element.id) { index, payment in
                                    AppListRow {
                                        Text(DateFormatters.display(from: payment.date))
                                            .font(AppTypography.bodySecondary)
                                            .foregroundStyle(AppColors.label)
                                    } trailing: {
                                        Text(String(format: "$%.4f", payment.amountPerShare))
                                            .font(AppTypography.cardTitle)
                                            .foregroundStyle(AppColors.label)
                                    }
                                    if index < min(context.recentPayments.count, 8) - 1 {
                                        AppGroupedDivider()
                                    }
                                }
                            }
                        }
                    }

                    AppScreenSection(title: "Summary") {
                        AppMetricStrip(items: [
                            ("Yield", formatPercent(context.dividendYieldPct)),
                            ("5Y CAGR", formatPercent(context.cagr5yPct)),
                            ("Streak", "\(context.consecutiveAnnualIncreases) yrs"),
                        ])
                        .appPanel(subtle: true)
                    }

                    DividendHistoryChartSection(dividends: context)

                    if !context.annualIncome.isEmpty {
                        AppDisclosureSection(
                            title: "Annual income",
                            footnote: "\(context.annualIncome.count) years",
                            isExpanded: $annualExpanded
                        ) {
                            AppGroupedList {
                                ForEach(Array(context.annualIncome.prefix(8).enumerated()), id: \.element.id) { index, row in
                                    AppListRow {
                                        Text(String(row.year))
                                            .font(AppTypography.bodySecondary)
                                            .foregroundStyle(AppColors.label)
                                    } trailing: {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(String(format: "$%.4f", row.totalPerShare))
                                                .font(AppTypography.cardTitle)
                                                .foregroundStyle(AppColors.label)
                                            Text(CurrencyFormatter.usd(row.incomeOnShares))
                                                .font(AppTypography.caption)
                                                .foregroundStyle(AppColors.secondaryLabel)
                                        }
                                    }
                                    if index < min(context.annualIncome.count, 8) - 1 {
                                        AppGroupedDivider()
                                    }
                                }
                            }
                        }
                    }

                    DividendSnowballCard(context: context, viewModel: viewModel)
                }
            } else if viewModel.earnings != nil || viewModel.incomeEarningsError != nil {
                AppEmptyMessage(
                    message: "No dividend history for \(viewModel.symbol). This is common for growth companies that do not pay dividends.",
                    systemImage: "dollarsign.circle"
                )
            }
        }
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f%%", value)
    }
}

// MARK: - Options tab

struct SymbolOptionsTab: View {
    let viewModel: SymbolDepthViewModel
    let symbolPositions: [Position]
    let assignmentRiskSummary: AssignmentRiskSummary?
    var onAnalyze: (String) -> Void

    var body: some View {
        ResearchDepthTabShell(tab: .more, viewModel: viewModel) {
            let intelligence = viewModel.symbolIntelligence
            let cspSummary = OptionsRiskHelpers.summarizeCSPCash(positions: symbolPositions, cashBalance: nil)

            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                if let assignmentRiskSummary,
                   OptionsRiskHelpers.hasAssignmentRisk(assignmentRiskSummary) {
                    AppScreenSection(title: "Assignment risk") {
                        AssignmentRiskSummaryCard(summary: assignmentRiskSummary)
                    }
                }

                if let cspSummary, cspSummary.totalReservedCash > 0 {
                    CashSecuredPutSummaryCard(summary: cspSummary, cashBalance: nil)
                }

                if let scorecard = intelligence?.optionsScorecard {
                    optionsScorecardSection(scorecard)
                }

                if let rolls = intelligence?.rollSuggestions, !rolls.isEmpty {
                    AppScreenSection(title: "Roll suggestions") {
                        VStack(spacing: 10) {
                            ForEach(rolls) { suggestion in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(suggestion.side.uppercased()) · \(CurrencyFormatter.usd(suggestion.currentStrike)) → \(CurrencyFormatter.usd(suggestion.suggestedStrike))")
                                        .font(.caption.weight(.semibold))
                                    Text(suggestion.rationale)
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                    Button("Ask AI about this roll") {
                                        onAnalyze(suggestion.rationale)
                                    }
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppColors.accentHighlight)
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.surfaceElevated.opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                }

                if let chain = intelligence?.optionChainPreview, !chain.rows.isEmpty {
                    AppScreenSection(
                        title: "Option chain preview",
                        footnote: chain.expiration.map { DateFormatters.display(from: $0) }
                    ) {
                        VStack(spacing: 8) {
                            ForEach(chain.rows.prefix(8)) { row in
                                HStack {
                                    Text(CurrencyFormatter.usd(row.strike))
                                        .font(.caption.monospacedDigit())
                                    Spacer()
                                    if let put = row.put {
                                        Text("P \(CurrencyFormatter.usd(put.mark ?? put.bid ?? 0))")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(AppColors.secondaryLabel)
                                    }
                                    if let call = row.call {
                                        Text("C \(CurrencyFormatter.usd(call.mark ?? call.bid ?? 0))")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(AppColors.secondaryLabel)
                                    }
                                }
                            }
                        }
                    }
                }

                if intelligence == nil ||
                    (!SymbolOptionsHelpers.hasOptionsContent(intelligence) &&
                     !SymbolOptionsHelpers.symbolHasOptionPositions(symbolPositions)) {
                    AppEmptyMessage(
                        message: "No options data yet for this symbol.",
                        systemImage: "target"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func optionsScorecardSection(_ scorecard: OptionsScorecard) -> some View {
        AppScreenSection(title: "Strike scorecard") {
            VStack(alignment: .leading, spacing: 12) {
                if !scorecard.puts.isEmpty {
                    candidateGroup(title: "Cash-secured puts", candidates: scorecard.puts)
                }
                if !scorecard.calls.isEmpty {
                    candidateGroup(title: "Covered calls", candidates: scorecard.calls)
                }
                if !scorecard.flags.isEmpty {
                    ForEach(scorecard.flags, id: \.self) { flag in
                        Text(flag)
                            .font(.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                }
            }
        }
    }

    private func candidateGroup(title: String, candidates: [OptionsStrikeCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            ForEach(candidates.prefix(4)) { candidate in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(CurrencyFormatter.usd(candidate.strike)) · \(DateFormatters.display(from: candidate.expiration))")
                        .font(.caption.weight(.semibold))
                    Text(candidate.rationale)
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.secondaryBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

// MARK: - Business tab

struct SymbolBusinessContent: View {
    @Environment(AccountContext.self) private var account
    let viewModel: SymbolDepthViewModel

    var body: some View {
        AppScreenSection(
            title: "Business",
            footnote: account.hasProFeature(.business)
                ? "Institutional business notes — mechanisms, limits, and asymmetry"
                : "Pro — structured business intelligence"
        ) {
            if account.hasProFeature(.business) {
                if let business = viewModel.business {
                    BusinessOverviewContent(business: business)
                } else {
                    AppEmptyMessage(message: "Business details are not available.")
                }
            } else {
                AppInlineBanner(
                    message: "Upgrade to Pro for structured business intelligence.",
                    tone: .neutral
                )
            }
        }
    }
}

struct SymbolBusinessTab: View {
    let viewModel: SymbolDepthViewModel

    var body: some View {
        ResearchDepthTabShell(tab: .analysis, viewModel: viewModel) {
            SymbolBusinessContent(viewModel: viewModel)
        }
    }
}

private struct BusinessOverviewContent: View {
    let business: BusinessBlock

    private var customersLine: String {
        business.primaryCustomers.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            businessBlock(title: "Business snapshot") {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: 8
                ) {
                    snapshotTile("Industry", business.industry)
                    snapshotTile("Primary product", business.primaryProduct)
                    snapshotTile("Customers", customersLine)
                    snapshotTile("Revenue model", business.revenueModel)
                }
            }

            bulletSection(title: "How they make money", items: business.howTheyMakeMoney)
            bulletSection(title: "Revenue visibility", items: business.revenueVisibility)

            if !business.advantages.isEmpty || !business.challenges.isEmpty {
                businessBlock(title: "Competitive position") {
                    HStack(alignment: .top, spacing: 12) {
                        bulletColumn(title: "Advantages", items: business.advantages, isRisk: false)
                        bulletColumn(title: "Challenges", items: business.challenges, isRisk: true)
                    }
                }
            }

            if !business.revenueDrivers.isEmpty || !business.constraints.isEmpty {
                businessBlock(title: "Growth drivers vs constraints") {
                    HStack(alignment: .top, spacing: 12) {
                        bulletColumn(title: "Revenue drivers", items: business.revenueDrivers, isRisk: false)
                        bulletColumn(title: "Constraints", items: business.constraints, isRisk: true)
                    }
                }
            }
            bulletSection(title: "Business risks", items: business.businessRisks, isRisk: true)
            bulletSection(title: "Key dependencies", items: business.dependencies)
        }
    }

    private func snapshotTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .tracking(0.3)
            Text(value.isEmpty ? "—" : value)
                .font(AppTypography.caption.weight(.medium))
                .foregroundStyle(AppColors.label)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.secondaryFill.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func businessBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            content()
        }
    }

    @ViewBuilder
    private func bulletSection(title: String, items: [String], isRisk: Bool = false) -> some View {
        if !items.isEmpty {
            businessBlock(title: title) {
                bulletList(items: items, isRisk: isRisk)
            }
        }
    }

    private func bulletColumn(title: String, items: [String], isRisk: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            bulletList(items: items, isRisk: isRisk)
        }
    }

    private func bulletList(items: [String], isRisk: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, id: \.self) { item in
                Text("• \(item)")
                    .font(.caption)
                    .foregroundStyle(isRisk ? AppColors.warning : AppColors.label)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Fundamentals tab

struct SymbolFundamentalsTab: View {
    let viewModel: SymbolDepthViewModel
    let assetType: String?

    @State private var secProfileExpanded = false

    private var isEtf: Bool {
        let normalized = assetType?.uppercased() ?? "STOCK"
        return normalized == "ETF" || normalized == "MUTUAL_FUND"
    }

    var body: some View {
        ResearchDepthTabShell(tab: .metrics, viewModel: viewModel) {
            if let block = viewModel.fundamentals {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    AppScreenSection(
                        title: isEtf ? "Fund valuation" : "Valuation",
                        footnote: isEtf
                            ? "Cost, yield, and composition"
                            : "Is the stock attractive at today's price?"
                    ) {
                        FundamentalsValuationSection(overview: block.overview)
                    }

                    if isEtf, let funds = block.etfFunds {
                        AppScreenSection(title: "Fund profile") {
                            EtfFundsOverviewSection(funds: funds)
                        }
                    }

                    if !isEtf {
                        if let signals = block.overview?.valuationSignals, !signals.isEmpty {
                            AppScreenSection(
                                title: "Valuation signals",
                                footnote: "Key inputs behind the thesis"
                            ) {
                                ValuationSignalsGrid(signals: signals)
                            }
                        }

                        if StreetAnalysisFormatters.hasStreetAnalysis(block.streetAnalysis) {
                            AppScreenSection(
                                title: "Wall Street analysis",
                                footnote: "Supporting consensus, targets, and estimate trends"
                            ) {
                                StreetAnalysisSection(street: block.streetAnalysis)
                            }
                        }

                        if StreetAnalysisFormatters.hasOwnership(block.streetAnalysis?.ownership) {
                            AppScreenSection(
                                title: "Ownership & insiders",
                                footnote: "Institutional holders and insider transaction history"
                            ) {
                                StreetOwnershipSection(
                                    ownership: block.streetAnalysis?.ownership,
                                    dataAsOf: block.streetAnalysis?.dataAsOf
                                )
                            }
                        }

                        AppDisclosureSection(
                            title: "SEC company profile",
                            footnote: "Registrant details from EDGAR",
                            isExpanded: $secProfileExpanded
                        ) {
                            Text("Open the Financials tab for filings, or view registrant metadata in a future SEC detail screen.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shared tab chrome

struct ResearchDepthTabShell<Content: View>: View {
    let tab: ResearchTab
    let viewModel: SymbolDepthViewModel
    private let content: () -> Content

    init(
        tab: ResearchTab,
        viewModel: SymbolDepthViewModel,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tab = tab
        self.viewModel = viewModel
        self.content = content
    }

    var body: some View {
        if viewModel.loadingTab == tab, isEmpty {
            AppLoadingState(message: "Loading \(tab.label.lowercased())…")
        } else if let error = viewModel.tabErrors[tab] {
            AppErrorState(message: error) {
                Task { await viewModel.reload(tab) }
            }
        } else {
            content()
        }
    }

    private var isEmpty: Bool {
        switch tab {
        case .overview:
            true
        case .analysis:
            viewModel.business == nil && viewModel.patternPrediction == nil
        case .metrics:
            viewModel.fundamentals == nil
        case .news:
            viewModel.news == nil && viewModel.companyNews == nil
        case .financials:
            viewModel.fundamentals == nil && viewModel.secFinancials == nil
        case .more:
            false
        }
    }
}
