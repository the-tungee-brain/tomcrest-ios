import SwiftUI

// MARK: - Overview tab (quote, performance, signals, chat)

struct SymbolOverviewTab: View {
    @Bindable var viewModel: SymbolOverviewViewModel
    @State private var signalsExpanded = false

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.bundle == nil {
                ResearchOverviewLoadingView()
            } else if let error = viewModel.errorMessage, viewModel.bundle == nil {
                AppErrorState(message: error) {
                    Task { await viewModel.reload() }
                }
            } else if let bundle = viewModel.bundle {
                overviewSections(bundle)
            }
        }
    }

    @ViewBuilder
    private func overviewSections(_ bundle: ResearchOverviewBundle) -> some View {
        SymbolQuoteHeroCard(bundle: bundle)

        AppScreenSection(title: "Performance") {
            SymbolPerformanceCard(performance: bundle.performance)
        }

        if !bundle.intelligence.signals.isEmpty {
            AppDisclosureSection(
                title: "Signals",
                footnote: "\(min(bundle.intelligence.signals.count, 5)) active",
                isExpanded: $signalsExpanded
            ) {
                SymbolSignalsCard(signals: bundle.intelligence.signals)
            }
        }

        ResearchChatPanel(viewModel: viewModel)
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

            earningsTextBlock(title: "Context", body: analysis.context)
            earningsBulletBlock(title: "Highlights", items: analysis.keyHighlights)
            earningsTextBlock(title: "Guidance", body: analysis.guidanceAndOutlook)
            earningsTextBlock(title: "Surprises", body: analysis.whatSurprised)
            earningsTextBlock(title: "Takeaway", body: analysis.investorTakeaway, emphasized: true)
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
                NewsHeadlineRow(item: item)
                if index < items.count - 1 {
                    AppGroupedDivider()
                }
            }
        }
    }

    @ViewBuilder
    private func transcriptContent(_ segments: [TranscriptSegment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(segments.prefix(8)) { segment in
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
            if segments.count > 8 {
                Text("\(segments.count - 8) more segments on web")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
    }
}

// MARK: - News tab

struct SymbolNewsTab: View {
    let viewModel: SymbolDepthViewModel

    var body: some View {
        ResearchDepthTabShell(tab: .news, viewModel: viewModel) {
            if let items = viewModel.news?.items {
                if items.isEmpty {
                    AppEmptyMessage(message: "No press releases in the last 90 days.")
                } else {
                    AppGroupedList {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            NewsHeadlineRow(item: item)
                            if index < items.count - 1 {
                                AppGroupedDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct NewsHeadlineRow: View {
    let item: NewsHeadline

    var body: some View {
        Group {
            if let url = item.url.flatMap(URL.init(string:)) {
                Link(destination: url) {
                    rowContent
                }
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.headline)
                .font(AppTypography.bodySecondary.weight(.medium))
                .foregroundStyle(AppColors.label)
                .lineSpacing(3)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                if !item.source.isEmpty {
                    Text(item.source)
                        .lineLimit(1)
                }
                if !item.source.isEmpty, !item.datetime.isEmpty {
                    Text("·")
                }
                if !item.datetime.isEmpty {
                    Text(formattedDate)
                }
                if item.url != nil {
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.secondaryLabel)

            // No URL — show one line of summary; full text opens via link when available.
            if item.url == nil, let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var formattedDate: String {
        let prefix = String(item.datetime.prefix(10))
        return EarningsFormatters.formatReportDate(prefix)
    }
}

// MARK: - Dividends tab

struct SymbolDividendsTab: View {
    let viewModel: SymbolDepthViewModel

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
                                        Text(payment.date)
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
                }
            }
        }
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f%%", value)
    }
}

// MARK: - Fundamentals tab

struct SymbolFundamentalsTab: View {
    let viewModel: SymbolDepthViewModel
    let assetType: String?

    @State private var overviewExpanded = false
    @State private var strengthExpanded = false

    var body: some View {
        ResearchDepthTabShell(tab: .fundamentals, viewModel: viewModel) {
            if let block = viewModel.fundamentals {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    // Metrics first — the tab’s primary job; narrative blocks stay collapsed.
                    if !block.metrics.isEmpty {
                        AppScreenSection(
                            title: ResearchTab.fundamentals.fundamentalsLabel(for: assetType)
                        ) {
                            AppGroupedList {
                                ForEach(Array(block.metrics.prefix(12).enumerated()), id: \.element.id) { index, metric in
                                    AppListRow {
                                        Text(metric.label)
                                            .font(AppTypography.bodySecondary)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                    } trailing: {
                                        Text(metric.value)
                                            .font(AppTypography.cardTitle)
                                            .foregroundStyle(AppColors.label)
                                            .multilineTextAlignment(.trailing)
                                    }
                                    if index < min(block.metrics.count, 12) - 1 {
                                        AppGroupedDivider()
                                    }
                                }
                            }
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

                    if let strength = block.strength {
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
                    }
                }
            }
        }
    }
}

// MARK: - Shared tab chrome

private struct ResearchDepthTabShell<Content: View>: View {
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
        case .overview: true
        case .earnings: viewModel.earnings == nil
        case .news: viewModel.news == nil
        case .dividends: viewModel.dividends == nil
        case .fundamentals: viewModel.fundamentals == nil
        }
    }
}
