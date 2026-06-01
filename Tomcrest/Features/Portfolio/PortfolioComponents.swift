import SwiftUI

// MARK: - Section tabs (web PortfolioSectionTabBar)

enum PortfolioSection: String, CaseIterable, Identifiable {
    case today
    case news
    case holdings
    case activity

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: "Today"
        case .news: "News"
        case .holdings: "Holdings"
        case .activity: "Activity"
        }
    }
}

struct PortfolioSectionTabBar: View {
    @Binding var selection: PortfolioSection
    var todayBadge: Int = 0
    var activityBadge: Int = 0

    var body: some View {
        AppSegmentedTabBar(
            tabs: PortfolioSection.allCases,
            selection: $selection,
            label: \.label,
            badge: { section in
                switch section {
                case .today: todayBadge
                case .activity: activityBadge
                default: 0
                }
            },
            accessibilityLabel: "Portfolio sections"
        )
    }
}

// MARK: - Portfolio news (web PortfolioNewsSection)

struct PortfolioNewsSection: View {
    let items: [PortfolioHoldingsNewsItem]
    let isLoading: Bool
    var onSymbolTap: ((String) -> Void)?

    var body: some View {
        AppScreenSection(
            title: "Headlines",
            footnote: "Recent stories from your largest holdings"
        ) {
            if isLoading, items.isEmpty {
                AppLoadingState(message: "Loading headlines…")
            } else if items.isEmpty {
                AppEmptyMessage(message: "No headlines available right now.")
            } else {
                AppGroupedList {
                    ForEach(Array(items.prefix(20).enumerated()), id: \.element.id) { index, item in
                        PortfolioNewsRow(item: item, onSymbolTap: onSymbolTap)
                        if index < min(items.count, 20) - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }
}

struct PortfolioNewsRow: View {
    let item: PortfolioHoldingsNewsItem
    var onSymbolTap: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    onSymbolTap?(item.symbol)
                } label: {
                    AppSymbolTag(symbol: item.symbol)
                }
                .buttonStyle(.plain)
                .disabled(onSymbolTap == nil)

                if let weight = item.weightPct {
                    Text(CurrencyFormatter.compactPercent(weight))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                Spacer(minLength: 0)
            }

            headlineLink

            HStack(spacing: 6) {
                if let source = item.source, !source.isEmpty {
                    Text(source).lineLimit(1)
                }
                if item.source?.isEmpty == false, item.publishedAt != nil {
                    Text("·")
                }
                if let publishedAt = item.publishedAt {
                    Text(DateFormatters.abbreviatedDay(from: publishedAt))
                }
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

    @ViewBuilder
    private var headlineLink: some View {
        if let url = item.url.flatMap(URL.init(string:)) {
            AppExternalLink(url: url) {
                headlineText
            }
        } else {
            headlineText
        }
    }

    private var headlineText: some View {
        Text(item.headline)
            .font(AppTypography.bodySecondary.weight(.medium))
            .foregroundStyle(AppColors.label)
            .lineSpacing(3)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Hero snapshot

struct PortfolioSnapshotCard: View {
    let snapshot: AccountSnapshot
    let syncedAtLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net liquidation")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .textCase(.uppercase)

                    Text(CurrencyFormatter.usd(snapshot.liquidationValue, fractionDigits: 0))
                        .font(AppTypography.heroMetric)
                        .foregroundStyle(AppColors.label)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Open P/L")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text(CurrencyFormatter.signedUsd(snapshot.totalOpenProfitLoss ?? 0))
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(profitTone(snapshot.totalOpenProfitLoss ?? 0))
                }
            }

            AppMetricStrip(items: [
                ("Buying power", CurrencyFormatter.usd(snapshot.buyingPower, fractionDigits: 0)),
                ("Cash", CurrencyFormatter.usd(snapshot.cashBalance, fractionDigits: 0)),
                ("Positions", "\(snapshot.positionCount)"),
            ])

            if let syncedAtLabel {
                Text("Updated \(syncedAtLabel)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
        }
        .appHeroPanel()
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

// MARK: - Morning brief (web PortfolioBriefSection — condensed for iOS)

struct MorningBriefCard: View {
    let lead: String?
    var changes: PortfolioChanges?
    var macroRegime: String?
    var digest: PortfolioDigest?
    var signals: [IntelligenceSignal] = []
    var isUrgentLead = false
    var generatedAt: String?
    var onGoDeeper: (() -> Void)?
    var onSymbolTap: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .frame(width: 32, height: 32)
                    .background(AppColors.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning brief")
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    if let generatedAt, let label = freshnessLabel(from: generatedAt) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(AppColors.tertiaryLabel)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(lead ?? "No brief yet.")
                .font(AppTypography.bodySecondary)
                .foregroundStyle(leadTextColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let changes, hasChangeDetails(changes) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Since yesterday")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)

                    if let pct = changes.liquidationValueChangePct {
                        Text(CurrencyFormatter.percent(pct))
                            .font(AppTypography.monoCaptionSemibold)
                            .foregroundStyle(profitTone(pct))
                    }

                    if let summary = changes.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surfaceElevated.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let macroRegime, !macroRegime.isEmpty {
                Text(macroRegime)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.secondaryFill)
                    .clipShape(Capsule())
            }

            if let sectorWeights = digest?.sectorWeights, !sectorWeights.isEmpty {
                briefSubsection(title: "Sector allocation", systemImage: "chart.pie.fill") {
                    VStack(spacing: 10) {
                        ForEach(Array(sectorWeights.prefix(5))) { sector in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(PortfolioBriefText.formatSectorLabel(sector.sector))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppColors.label)
                                    Spacer(minLength: 0)
                                    Text(CurrencyFormatter.compactPercent(sector.weightPct))
                                        .font(AppTypography.monoCaption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                }
                                Capsule()
                                    .fill(AppColors.secondaryBackground)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(AppColors.accentHighlight.opacity(0.85))
                                            .scaleEffect(
                                                x: min(sector.weightPct / 100, 1),
                                                y: 1,
                                                anchor: .leading
                                            )
                                    }
                                    .frame(height: 6)
                                Text(sectorSymbolPreview(sector.symbols))
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.tertiaryLabel)
                            }
                        }
                    }
                }
            }

            if let earnings = digest?.earningsThisWeek, !earnings.isEmpty {
                briefSubsection(title: "Earnings this week", systemImage: "calendar") {
                    AppWrappingChipGrid(items: earnings, minimumChipWidth: 72) { symbol in
                        Button {
                            onSymbolTap?(symbol)
                        } label: {
                            Text(symbol)
                                .font(AppTypography.monoCaption2Semibold)
                                .foregroundStyle(AppColors.label)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(AppColors.insetSurface)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule().stroke(AppColors.separator, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(onSymbolTap == nil)
                    }
                }
            }

            if let topNews = digest?.topNews, !topNews.isEmpty {
                briefSubsection(title: "Top holdings news", systemImage: "newspaper.fill") {
                    VStack(spacing: 8) {
                        ForEach(Array(topNews.prefix(4))) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Button {
                                        onSymbolTap?(item.symbol)
                                    } label: {
                                        AppSymbolTag(symbol: item.symbol)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(onSymbolTap == nil)

                                    if let weight = item.weightPct {
                                        Text(CurrencyFormatter.compactPercent(weight))
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                    }

                                    if let sentiment = item.sentiment, !sentiment.isEmpty {
                                        Text(sentiment.replacingOccurrences(of: "_", with: " "))
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(AppColors.secondaryLabel)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(AppColors.secondaryBackground)
                                            .clipShape(Capsule())
                                    }
                                }

                                if let url = item.url.flatMap(URL.init(string:)) {
                                    AppExternalLink(url: url) {
                                        Text(item.headline)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(AppColors.label)
                                            .lineSpacing(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                } else {
                                    Text(item.headline)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppColors.label)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.surfaceElevated.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppColors.panelBorder, lineWidth: 1)
                            }
                        }
                    }
                }
            }

            if !signals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signals")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)

                    ForEach(signals) { signal in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(severityColor(signal.severity))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(signal.message)
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                                .lineSpacing(2)
                        }
                    }
                }
            }

            if let onGoDeeper {
                Button(action: onGoDeeper) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption.weight(.semibold))
                        Text("Go deeper with diversification analysis")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppColors.accentHighlight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.accentMuted.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .appPanel(subtle: true)
    }

    @ViewBuilder
    private func briefSubsection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            content()
        }
    }

    private func sectorSymbolPreview(_ symbols: [String]) -> String {
        let preview = symbols.prefix(4).joined(separator: ", ")
        if symbols.count > 4 {
            return "\(preview)…"
        }
        return preview
    }

    private var leadTextColor: Color {
        if lead == nil { return AppColors.secondaryLabel }
        if isUrgentLead { return AppColors.warning }
        return AppColors.label
    }

    private func hasChangeDetails(_ changes: PortfolioChanges) -> Bool {
        changes.summary?.isEmpty == false || changes.liquidationValueChangePct != nil
    }

    private func freshnessLabel(from iso: String) -> String? {
        let formatted = DateFormatters.display(from: iso)
        guard formatted != "—" else { return nil }
        return "Updated \(formatted)"
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }

    private func severityColor(_ severity: SignalSeverity) -> Color {
        switch severity {
        case .critical: AppColors.error
        case .warning: AppColors.warning
        case .watch: AppColors.accentHighlight
        case .info: AppColors.tertiaryLabel
        }
    }
}

// MARK: - Attention (web PortfolioAttentionSection)

struct PortfolioAttentionSection: View {
    let taxItems: [TaxAlertItem]
    let alerts: [ProactiveAlert]
    let attentionQueue: [AttentionItem]
    let suggestedActions: [SuggestedAnalysisAction]
    let itemCount: Int
    let onDismiss: (AttentionItem) -> Void
    let onQuickAction: (String) -> Void

    private var useAttentionQueue: Bool { !attentionQueue.isEmpty }

    private var generalAlerts: [ProactiveAlert] {
        useAttentionQueue ? [] : IntelligenceHelpers.dedupeAlerts(
            alerts.filter { !IntelligenceHelpers.isTaxAlert($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            attentionHeader

            if itemCount == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All clear")
                            .font(AppTypography.bodySecondary.weight(.semibold))
                            .foregroundStyle(AppColors.label)
                        Text("No tax flags, risk alerts, or suggested follow-ups right now.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }
                .padding(16)
            } else {
                if !taxItems.isEmpty {
                    SymbolTaxWashSaleStrip(items: taxItems) { item in
                        onQuickAction(item.actionId)
                    }
                    .padding(.top, 12)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if useAttentionQueue {
                        attentionSubsection(title: "Priority queue") {
                            ForEach(Array(attentionQueue.prefix(5))) { item in
                                PortfolioAttentionRow(
                                    label: item.label,
                                    reason: item.reason,
                                    symbol: item.symbol,
                                    actionId: item.action,
                                    canDismiss: item.alertId != nil,
                                    onAsk: { onQuickAction(item.action) },
                                    onDismiss: { onDismiss(item) }
                                )
                            }
                        }
                    } else if !generalAlerts.isEmpty {
                        attentionSubsection(title: "Alerts") {
                            ForEach(Array(generalAlerts.prefix(5))) { alert in
                                PortfolioAttentionRow(
                                    label: alert.label,
                                    reason: alert.reason,
                                    symbol: alert.symbol,
                                    actionId: IntelligenceHelpers.alertToQuickActionId(alert),
                                    canDismiss: false,
                                    onAsk: { onQuickAction(IntelligenceHelpers.alertToQuickActionId(alert)) }
                                )
                            }
                        }
                    }

                    if !suggestedActions.isEmpty {
                        attentionSubsection(title: "From recent trades") {
                            PortfolioSuggestedActionChips(
                                actions: suggestedActions,
                                onSelect: { onQuickAction($0.action) }
                            )
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .appPanel()
    }

    private var attentionHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(taxItems.isEmpty ? AppColors.accentHighlight : Color(hex: 0xfbbf24))
                .frame(width: 32, height: 32)
                .background(
                    taxItems.isEmpty
                        ? AppColors.accentMuted
                        : Color(hex: 0xf59e0b, opacity: 0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Needs attention")
                    .font(AppTypography.bodySecondary.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(itemCount == 0
                    ? "Nothing flagged right now"
                    : "\(itemCount) item\(itemCount == 1 ? "" : "s") need your review")
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .background(AppColors.secondaryBackground.opacity(0.5))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func attentionSubsection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            content()
        }
    }
}

private struct PortfolioAttentionRow: View {
    let label: String
    let reason: String
    let symbol: String?
    let actionId: String
    var canDismiss = false
    let onAsk: () -> Void
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.label)
                    if let symbol {
                        AppSymbolTag(symbol: symbol)
                    }
                }
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(2)
            }

            HStack(spacing: 8) {
                Button(action: onAsk) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.semibold))
                        Text("Ask AI")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppColors.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if canDismiss, let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .frame(width: Layout.minTouchTarget, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss alert")
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(AppColors.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.separator, lineWidth: 1)
        }
    }
}

private struct PortfolioSuggestedActionChips: View {
    let actions: [SuggestedAnalysisAction]
    let onSelect: (SuggestedAnalysisAction) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 132), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(actions) { action in
                Button {
                    onSelect(action)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.accentHighlight)
                        Text(action.label)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(AppColors.label)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.insetSurface)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(AppColors.separator, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(action.reason)
            }
        }
    }
}

// MARK: - Holdings

struct HoldingsSection: View {
    let positions: [Position]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppGroupedList {
                ForEach(Array(positions.prefix(10).enumerated()), id: \.element.id) { index, position in
                    HoldingRow(position: position)
                    if index < min(positions.count, 10) - 1 {
                        AppGroupedDivider()
                    }
                }
            }

            if positions.count > 10 {
                Text("+ \(positions.count - 10) more positions")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .padding(.top, 10)
            }
        }
    }
}

private struct HoldingRow: View {
    let position: Position

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                SymbolAvatar(symbol: position.displaySymbol, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(position.displaySymbol)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.label)
                    Text(CurrencyFormatter.usd(position.marketValue, fractionDigits: 0))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 3) {
                Text(CurrencyFormatter.compactPercent(position.portfolioWeightPct))
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(AppColors.secondaryLabel)
                Text(CurrencyFormatter.signedUsd(position.openProfitLoss ?? 0))
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(profitTone(position.openProfitLoss ?? 0))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

// MARK: - Empty / connect states

struct SchwabConnectPrompt: View {
    var systemImage = "link.circle.fill"
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        AppEmptyState(
            systemImage: systemImage,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

// MARK: - Loading skeleton

struct PortfolioLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            skeletonBlock(height: 180)
            skeletonBlock(height: 96)
            skeletonBlock(height: 140)
        }
        .redacted(reason: .placeholder)
    }

    private func skeletonBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.secondaryBackground)
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
    }
}
