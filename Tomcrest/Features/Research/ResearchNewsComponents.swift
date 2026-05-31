import SwiftUI

// MARK: - Feed scope (mirrors web ResearchNewsHub tabs)

enum NewsFeedScope: String, CaseIterable, Identifiable {
    case all
    case coverage
    case official

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .coverage: "Coverage"
        case .official: "Press"
        }
    }
}

enum NewsSentimentFormatters {
    static func overallLabel(_ raw: String) -> String {
        switch raw {
        case "strongly_bullish": "Strongly bullish"
        case "bullish": "Bullish"
        case "bearish": "Bearish"
        case "strongly_bearish": "Strongly bearish"
        default: "Neutral"
        }
    }

    static func overallTone(_ raw: String) -> AppStatusPill.Tone {
        switch raw {
        case "strongly_bullish", "bullish": .success
        case "bearish", "strongly_bearish": .error
        default: .neutral
        }
    }

    static func itemTone(_ raw: String) -> AppStatusPill.Tone {
        switch raw {
        case "bullish": .success
        case "bearish": .error
        default: .neutral
        }
    }

    static func formatMetadata(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return value
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private let newsPreviewLimit = 4

// MARK: - Scope tab bar (web appTabBar + appTabLink pattern)

struct NewsFeedScopeBar: View {
    @Binding var scope: NewsFeedScope
    let officialCount: Int
    let coverageCount: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NewsFeedScope.allCases) { tab in
                let isSelected = scope == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scope = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.label)
                            .font(.caption.weight(.semibold))
                        if let count = count(for: tab), count > 0 {
                            Text(count > 99 ? "99+" : "\(count)")
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isSelected ? AppColors.accentMuted : AppColors.secondaryFill)
                                .foregroundStyle(isSelected ? AppColors.accentHighlight : AppColors.secondaryLabel)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(isSelected ? AppColors.accentHighlight : AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? AppColors.accentMuted : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("News feed sections")
    }

    private func count(for tab: NewsFeedScope) -> Int? {
        switch tab {
        case .all:
            let total = officialCount + coverageCount
            return total > 0 ? total : nil
        case .coverage:
            return coverageCount > 0 ? coverageCount : nil
        case .official:
            return officialCount > 0 ? officialCount : nil
        }
    }
}

// MARK: - AI brief (web NewsOverviewContent)

struct NewsAiBriefCard: View {
    let analytics: StockNewsView

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppStatusPill(
                    label: NewsSentimentFormatters.overallLabel(analytics.overallSentiment),
                    uppercase: false,
                    tone: NewsSentimentFormatters.overallTone(analytics.overallSentiment)
                )
                if let score = analytics.actionabilityScore {
                    Text("Actionability \(score)/5")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(analytics.summary)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.label)
                    .lineSpacing(3)
                if let takeaway = analytics.investorTakeaway, !takeaway.isEmpty {
                    Text(takeaway)
                        .font(AppTypography.bodySecondary.weight(.medium))
                        .foregroundStyle(AppColors.label)
                        .lineSpacing(3)
                }
            }
            .appPanel(subtle: true)
        }
    }
}

struct NewsAnalyzePromptCard: View {
    let storyCount: Int
    let isAnalyzing: Bool
    let onAnalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ready to analyze")
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.accentHighlight)
            Text(storyCount > 0
                 ? "Run AI analysis for sentiment, summaries, and a synthesized brief."
                 : "Headlines will appear once market coverage loads.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(3)
            Button(isAnalyzing ? "Analyzing…" : "Analyze news", action: onAnalyze)
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(isAnalyzing || storyCount == 0)
        }
        .appPanel(subtle: true)
    }
}

struct NewsAnalysisDetailSections: View {
    let analytics: StockNewsView
    @State private var contextExpanded = false
    @State private var insightsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            AppDisclosureSection(
                title: "Market context",
                isExpanded: $contextExpanded
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    metadataRow("Dominant driver", NewsSentimentFormatters.formatMetadata(analytics.dominantDriver))
                    metadataRow("Impact horizon", NewsSentimentFormatters.formatMetadata(analytics.marketImpactHorizon))
                }
            }

            AppDisclosureSection(
                title: "Insights & risks",
                footnote: "\(analytics.insights.count + analytics.risks.count)",
                isExpanded: $insightsExpanded
            ) {
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    if !analytics.insights.isEmpty {
                        bulletBlock(title: "Key insights", items: Array(analytics.insights.prefix(4)))
                    }
                    if !analytics.risks.isEmpty {
                        bulletBlock(title: "Risks", items: Array(analytics.risks.prefix(4)))
                    }
                    if let deep = analytics.deepAnalysis, !deep.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DEEP ANALYSIS")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.tertiaryLabel)
                            Text(deep)
                                .font(AppTypography.bodySecondary)
                                .foregroundStyle(AppColors.label)
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.label)
        }
    }

    private func bulletBlock(title: String, items: [String]) -> some View {
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
}

// MARK: - Headline lists

struct AppEnrichedNewsHeadlineRow: View {
    let item: EnrichedNewsItem
    var showSentiment = true

    var body: some View {
        if let url = item.url.flatMap(URL.init(string:)) {
            AppExternalLink(url: url) {
                rowContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.headline)
                    .font(AppTypography.bodySecondary.weight(.medium))
                    .foregroundStyle(AppColors.label)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showSentiment {
                    AppStatusPill(
                        label: item.sentiment.capitalized,
                        uppercase: false,
                        tone: NewsSentimentFormatters.itemTone(item.sentiment)
                    )
                }
            }

            if !item.summary.isEmpty {
                Text(item.summary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 6) {
                if !item.source.isEmpty {
                    Text(item.source).lineLimit(1)
                }
                if !item.source.isEmpty {
                    Text("·")
                }
                Text(DateFormatters.abbreviatedDay(from: item.datetime))
                if item.url != nil {
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.tertiaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct NewsHeadlinesGroupedList: View {
    let enrichedItems: [EnrichedNewsItem]
    var showSentiment = true
    var limit: Int?

    var body: some View {
        let items = limit.map { Array(enrichedItems.prefix($0)) } ?? enrichedItems
        AppGroupedList {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                AppEnrichedNewsHeadlineRow(item: item, showSentiment: showSentiment)
                if index < items.count - 1 {
                    AppGroupedDivider()
                }
            }
        }
    }
}

struct PressReleasesGroupedList: View {
    let items: [NewsHeadline]
    var limit: Int?

    var body: some View {
        let rows = limit.map { Array(items.prefix($0)) } ?? items
        AppGroupedList {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                AppNewsHeadlineRow(item: item)
                if index < rows.count - 1 {
                    AppGroupedDivider()
                }
            }
        }
    }
}

struct NewsViewAllButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppColors.accentHighlight)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

enum NewsFeedPreview {
    static let limit = newsPreviewLimit
}
