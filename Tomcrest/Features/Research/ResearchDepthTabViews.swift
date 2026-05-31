import SwiftUI
import Charts

// MARK: - Overview tab (quote, performance, signals, chat)

struct SymbolOverviewTab: View {
    @Environment(AccountContext.self) private var account
    @Environment(AssistantPresenter.self) private var assistant
    @Bindable var viewModel: SymbolOverviewViewModel
    @Bindable var positionViewModel: SymbolPositionViewModel
    let bundle: ResearchOverviewBundle?
    var onQuickAction: (String) -> Void = { _ in }
    @State private var signalsExpanded = false

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
        .task {
            await positionViewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func overviewSections(_ bundle: ResearchOverviewBundle) -> some View {
        SymbolQuoteHeroCard(bundle: bundle)

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

        BigPictureSection(
            summary: bundle.summary,
            isLoading: viewModel.isBigPictureLoading,
            errorMessage: viewModel.bigPictureError,
            onRefresh: {
                Task { await viewModel.refreshBigPicture() }
            }
        )

        AppScreenSection(title: "Performance") {
            SymbolPerformanceCard(performance: bundle.performance)
        }

        if !isEtfAsset(bundle.assetType) {
            StreetAnalysisOverviewPreview(street: bundle.streetAnalysis)
        } else {
            EtfHoldingsOverviewPreview(holdings: bundle.etfHoldings)
            if let funds = bundle.etfFunds {
                AppScreenSection(title: "Fund profile") {
                    EtfFundsOverviewSection(funds: funds)
                }
            }
        }

        SymbolIntelligenceOverviewPanel(signals: bundle.intelligence.signals) { prompt in
            assistant.openSymbol(viewModel.symbol, prompt: prompt, sendImmediately: true)
        }

        AppScreenSection(title: "Company snapshot") {
            VStack(alignment: .leading, spacing: 8) {
                snapshotRow("Sector", bundle.snapshot.sector)
                snapshotRow("Country", bundle.snapshot.country)
                snapshotRow("Market cap", bundle.snapshot.marketCap)
                if let range = bundle.snapshot.range52w {
                    snapshotRow("52-week range", range)
                }
            }
            .appPanel(subtle: true)
        }

        AssistantLauncherRow(
            title: "Ask about \(viewModel.symbol)",
            subtitle: "Research assistant — quality, risks, and valuation"
        ) {
            assistant.openSymbol(viewModel.symbol)
        }
    }

    private func snapshotRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.label)
        }
    }

    private func isEtfAsset(_ assetType: String?) -> Bool {
        let normalized = assetType?.uppercased() ?? ""
        return normalized == "ETF" || normalized == "MUTUAL_FUND" || normalized == "INDEX"
    }
}

// MARK: - Position tab (web SymbolPositionContent)

struct SymbolPositionTab: View {
    @Bindable var viewModel: SymbolPositionViewModel
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

                    if viewModel.hasOptionPositions {
                        OptionsTabPrompt(symbol: viewModel.symbol) {
                            onQuickAction("__open_options_tab__")
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
        ResearchDepthTabShell(tab: .earnings, viewModel: viewModel) {
            if let earnings = viewModel.earnings {
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
                                    await viewModel.selectHistoryEvent(
                                        event,
                                        includeAnalysis: account.hasProFeature(.earningsAi)
                                    )
                                }
                            }

                            if let selected = viewModel.selectedHistoryEvent {
                                EarningsDetailSection(
                                    previewEvent: selected,
                                    detail: viewModel.earningsDetail,
                                    isLoading: viewModel.earningsDetailLoading,
                                    error: viewModel.earningsDetailError,
                                    earningsAiAllowed: account.hasProFeature(.earningsAi)
                                )
                            }
                        }
                    }
                }
                .task(id: viewModel.selectedHistoryEvent?.id) {
                    guard viewModel.selectedHistoryEvent != nil else { return }
                    await viewModel.loadEarningsDetail(
                        includeAnalysis: account.hasProFeature(.earningsAi)
                    )
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
                    if isLoading, detail?.analysis == nil {
                        earningsAnalysisSkeleton
                    } else if let analysis = detail?.analysis {
                        earningsAnalysisBlock(analysis)
                    } else if !isLoading, error == nil {
                        Text("AI analysis is not available for this quarter.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
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
        ResearchDepthTabShell(tab: .dividends, viewModel: viewModel) {
            if let context = viewModel.dividends {
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
        ResearchDepthTabShell(tab: .options, viewModel: viewModel) {
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

struct SymbolBusinessTab: View {
    @Environment(AccountContext.self) private var account
    let viewModel: SymbolDepthViewModel

    var body: some View {
        ResearchDepthTabShell(tab: .business, viewModel: viewModel) {
            AppScreenSection(
                title: "Business",
                footnote: account.hasProFeature(.business)
                    ? "How the company works, competes, and grows"
                    : "Pro — AI overview of the business model, moat, and risks"
            ) {
                if account.hasProFeature(.business) {
                    if let business = viewModel.business {
                        BusinessOverviewContent(business: business)
                    } else {
                        AppEmptyMessage(message: "Business details are not available.")
                    }
                } else {
                    AppInlineBanner(
                        message: "Upgrade to Pro for AI business model analysis, moat, and risk breakdowns.",
                        tone: .neutral
                    )
                }
            }
        }
    }
}

private enum BusinessSegmentChipMetrics {
    static let minHeight: CGFloat = 36
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 12
}

private struct BusinessOverviewContent: View {
    let business: BusinessBlock

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            let atAGlance = BusinessArticleSupport.atAGlance(from: business)
            if !atAGlance.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("At a glance")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(atAGlance, id: \.self) { item in
                            Text("• \(item)")
                                .font(AppTypography.bodySecondary.weight(.medium))
                                .foregroundStyle(AppColors.label)
                                .lineSpacing(3)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.accentMuted.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            if !business.segments.isEmpty {
                businessBlock(title: "Segments") {
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(Array(segmentRows.enumerated()), id: \.offset) { _, row in
                            GridRow(alignment: .top) {
                                if row.count == 1 {
                                    segmentChip(row[0])
                                        .gridCellColumns(2)
                                } else {
                                    segmentChip(row[0])
                                    segmentChip(row[1])
                                }
                            }
                        }
                    }
                }
            }

            proseBlock(title: "What they do", text: business.whatTheyDo)
            proseBlock(title: "How they make money", text: business.revenueNotes)
            proseBlock(title: "Customers & markets", text: business.customersAndMarkets)
            proseBlock(title: "Competitive landscape", text: business.competitiveLandscape)
            proseBlock(title: "Moat & differentiators", text: business.moatAndDifferentiators)

            if !business.growthDrivers.isEmpty || !business.keyRisks.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    bulletColumn(title: "Growth drivers", items: business.growthDrivers, isRisk: false)
                    bulletColumn(title: "Business risks", items: business.keyRisks, isRisk: true)
                }
            }
        }
    }

    private var segmentRows: [[String]] {
        stride(from: 0, to: business.segments.count, by: 2).map { start in
            Array(business.segments[start..<min(start + 2, business.segments.count)])
        }
    }

    private func segmentChip(_ segment: String) -> some View {
        Text(segment)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppColors.label)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, BusinessSegmentChipMetrics.horizontalPadding)
            .padding(.vertical, BusinessSegmentChipMetrics.verticalPadding)
            .frame(minHeight: BusinessSegmentChipMetrics.minHeight)
            .background(AppColors.surfaceElevated.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: BusinessSegmentChipMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BusinessSegmentChipMetrics.cornerRadius, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
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
    private func proseBlock(title: String, text: String) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            businessBlock(title: title) {
                Text(trimmed)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.label)
                    .lineSpacing(4)
            }
        }
    }

    private func bulletColumn(title: String, items: [String], isRisk: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
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
}

// MARK: - Fundamentals tab

struct SymbolFundamentalsTab: View {
    @Environment(AccountContext.self) private var account
    let viewModel: SymbolDepthViewModel
    let assetType: String?

    @State private var overviewExpanded = false
    @State private var strengthExpanded = false

    private var isEtf: Bool {
        let normalized = assetType?.uppercased() ?? "STOCK"
        return normalized == "ETF" || normalized == "MUTUAL_FUND"
    }

    var body: some View {
        ResearchDepthTabShell(tab: .fundamentals, viewModel: viewModel) {
            if let block = viewModel.fundamentals {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if isEtf, let funds = block.etfFunds {
                        AppScreenSection(title: "Fund profile") {
                            EtfFundsOverviewSection(funds: funds)
                        }
                    }

                    // Metrics first — the tab’s primary job; narrative blocks stay collapsed.
                    if !block.metrics.isEmpty {
                        AppScreenSection(
                            title: ResearchTab.fundamentals.fundamentalsLabel(for: assetType)
                        ) {
                            GroupedKeyMetricsSection(metrics: block.metrics)
                        }
                    }

                    if let overview = block.overview?.atAGlance, !overview.isEmpty {
                        AppDisclosureSection(title: "Overview", isExpanded: $overviewExpanded) {
                            Text(overview)
                                .font(AppTypography.bodySecondary)
                                .foregroundStyle(AppColors.label)
                                .lineSpacing(4)
                        }
                    } else if let note = block.overviewNote, !note.isEmpty {
                        AppDisclosureSection(title: "Overview", isExpanded: $overviewExpanded) {
                            Text(note)
                                .font(AppTypography.bodySecondary)
                                .foregroundStyle(AppColors.secondaryLabel)
                                .lineSpacing(3)
                        }
                    }

                    if account.hasProFeature(.financialStrength), let strength = block.strength {
                        AppDisclosureSection(
                            title: "Financial strength",
                            footnote: strength.rating.capitalized,
                            isExpanded: $strengthExpanded
                        ) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(strength.headline)
                                    .font(AppTypography.cardTitle)
                                    .foregroundStyle(AppColors.label)
                                Text("Score \(strength.score)/100")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                    } else if !account.hasProFeature(.financialStrength), !isEtf {
                        AppInlineBanner(
                            message: "Upgrade to Pro for financial strength analysis.",
                            tone: .neutral
                        )
                    }

                    if !isEtf {
                        if StreetAnalysisFormatters.hasStreetAnalysis(block.streetAnalysis) {
                            AppScreenSection(
                                title: "Wall Street analysis",
                                footnote: "Analyst consensus, price targets, and estimate trends"
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
        case .overview, .position: true
        case .earnings: viewModel.earnings == nil
        case .news: viewModel.news == nil
        case .dividends: viewModel.dividends == nil
        case .fundamentals: viewModel.fundamentals == nil
        case .financials: viewModel.fundamentals == nil
        case .composition: viewModel.etfHoldings == nil
        case .business: viewModel.business == nil
        case .options: viewModel.symbolIntelligence == nil
        case .backtest: viewModel.dividends == nil
        }
    }
}
