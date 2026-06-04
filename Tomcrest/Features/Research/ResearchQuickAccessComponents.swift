import SwiftUI

struct WatchlistToggleButton: View {
    @Environment(WatchlistStore.self) private var watchlistStore
    let symbol: String
    var companyName: String?
    var iconOnly = true

    @State private var isPreparing = false
    @State private var showSaveSheet = false

    var body: some View {
        @Bindable var store = watchlistStore
        let watching = store.contains(symbol)

        Button {
            Task {
                isPreparing = true
                await watchlistStore.ensureLoaded()
                isPreparing = false
                showSaveSheet = true
            }
        } label: {
            if iconOnly {
                Group {
                    if isPreparing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: watching ? "star.fill" : "star")
                            .font(.body.weight(.semibold))
                    }
                }
                .foregroundStyle(watching ? AppColors.accentHighlight : AppColors.secondaryLabel)
                .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
            } else {
                HStack(spacing: 5) {
                    if isPreparing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: watching ? "star.fill" : "star")
                    }
                    Text(watching ? "Watching" : "Watchlist")
                }
                .smallOutlinedButtonLabel(accent: watching)
            }
        }
        .buttonStyle(.plain)
        .disabled(isPreparing)
        .accessibilityLabel(
            watching
                ? "Manage \(symbol.uppercased()) in watchlist folders"
                : "Add \(symbol.uppercased()) to a watchlist folder"
        )
        .sheet(isPresented: $showSaveSheet) {
            WatchlistSaveSymbolSheet(symbol: symbol, companyName: companyName)
        }
    }
}

/// Research + watchlist actions shared by Top Movers and Emerging Leaders detail rows.
struct SymbolInvestigateActionBar: View {
    let symbol: String
    var onResearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INVESTIGATE NEXT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Token.textTertiary)
                .tracking(0.5)
            HStack(alignment: .center, spacing: 8) {
                Button(action: onResearch) {
                    Label("Research", systemImage: "doc.text.magnifyingglass")
                        .labelStyle(.titleAndIcon)
                        .imageScale(.small)
                }
                .buttonStyle(SymbolOutlinedButtonStyle())

                WatchlistToggleButton(symbol: symbol, iconOnly: false)
            }
        }
    }
}

struct SymbolOutlinedButtonStyle: ButtonStyle {
    var accent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .smallOutlinedButtonLabel(accent: accent)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private extension View {
    func smallOutlinedButtonLabel(accent: Bool = false) -> some View {
        font(.caption.weight(.semibold))
            .foregroundStyle(accent ? AppColors.accentHighlight : AppColors.label)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        accent
                            ? AppColors.accentHighlight.opacity(0.55)
                            : AppColors.separator,
                        lineWidth: 1
                    )
            }
    }
}

struct ResearchWatchlistSection: View {
    let symbols: [String]
    let onSelect: (String) -> Void
    var onViewAll: (() -> Void)? = nil

    var body: some View {
        AppScreenSection(title: "Your watchlist") {
            ResearchSymbolChipRow(symbols: symbols, style: .watchlist, onSelect: onSelect)

            if let onViewAll {
                Button("View all", action: onViewAll)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .buttonStyle(.plain)
                    .padding(.top, 4)
            }
        }
    }
}

struct ResearchRecentSymbolsSection: View {
    let symbols: [String]
    let onClear: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recently viewed")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                Spacer()
                Button("Clear", action: onClear)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .buttonStyle(.plain)
            }

            ResearchSymbolChipRow(symbols: symbols, style: .recent, onSelect: onSelect)
        }
    }
}

private struct ResearchSymbolChipRow: View {
    enum Style {
        case watchlist
        case recent
    }

    let symbols: [String]
    let style: Style
    let onSelect: (String) -> Void

    var body: some View {
        AppHorizontalScrollRow {
            HStack(spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    chipButton(for: symbol)
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton(for symbol: String) -> some View {
        Button {
            onSelect(symbol)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: style == .watchlist ? "star.fill" : "clock")
                    .font(.caption2.weight(.semibold))
                Text(symbol)
                    .font(AppTypography.monoCaptionSemibold)
            }
            .foregroundStyle(
                style == .watchlist
                    ? AppColors.accentHighlight
                    : AppColors.label
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                style == .watchlist
                    ? AppColors.accentMuted
                    : AppColors.insetSurface
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        style == .watchlist
                            ? AppColors.accentHighlight.opacity(0.3)
                            : AppColors.separator,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

struct StrategyPlaybookQuickLinksSection: View {
    @Environment(AuthSession.self) private var auth
    let onSelectSymbol: (String) -> Void

    @State private var profile: UserInvestmentProfile?
    @State private var catalog: [StrategyCatalogItem] = []
    @State private var recommendations: StrategyRecommendations?

    private var symbols: [String] {
        StrategyPlaybookHelpers.symbols(from: profile)
    }

    var body: some View {
        Group {
            if let strategyId = profile?.primaryStrategy, !symbols.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Strategy playbook")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .textCase(.uppercase)
                        Text(
                            StrategyPlaybookHelpers.formatPlaybookTitle(
                                strategyId: strategyId,
                                catalogItem: catalog.first { $0.id == strategyId }
                            )
                        )
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        Text("Jump to a playbook symbol — status and next steps appear on each research page.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }

                    AppWrappingChipGrid(items: symbols, minimumChipWidth: 140, spacing: 8) { symbol in
                        playbookSymbolChip(symbol: symbol, strategyId: strategyId)
                    }
                }
                .padding(16)
                .appPanel(subtle: true)
            }
        }
        .task(id: auth.accessToken) {
            await loadStrategyContext()
        }
    }

    @ViewBuilder
    private func playbookSymbolChip(symbol: String, strategyId: String) -> some View {
        let status = recommendations?.symbolStatuses?.first { $0.symbol == symbol.uppercased() }
        let needsAttention = status.map(StrategyPlaybookHelpers.symbolNeedsAttention) ?? false

        Button {
            onSelectSymbol(symbol)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if needsAttention {
                        Circle()
                            .fill(AppColors.accentHighlight)
                            .frame(width: 6, height: 6)
                    }
                    Text(symbol)
                        .font(AppTypography.monoCaptionSemibold)
                        .foregroundStyle(AppColors.label)
                }
                Text(playbookSubtitle(for: status, strategyId: strategyId))
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minWidth: 88, alignment: .leading)
            .background(needsAttention ? AppColors.accentMuted.opacity(0.35) : AppColors.insetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func playbookSubtitle(for status: StrategySymbolStatus?, strategyId: String) -> String {
        guard let status else { return "On playbook" }
        let label = status.statusLabel
        let badge = StrategyPlaybookHelpers.playbookHoldBadge(status)
        return "\(label) · \(badge)"
    }

    private func loadStrategyContext() async {
        guard let accessToken = auth.accessToken else {
            profile = nil
            catalog = []
            recommendations = nil
            return
        }

        do {
            async let profileTask = StrategyService.fetchProfile(accessToken: accessToken)
            async let catalogTask = StrategyService.fetchCatalog(accessToken: accessToken)
            let loadedProfile = try await profileTask
            let loadedCatalog = try await catalogTask
            profile = loadedProfile
            catalog = loadedCatalog

            if let strategyId = loadedProfile?.primaryStrategy {
                recommendations = try await StrategyService.fetchRecommendations(
                    strategyId: strategyId,
                    accessToken: accessToken
                )
            } else {
                recommendations = nil
            }
        } catch {
            profile = nil
            catalog = []
            recommendations = nil
        }
    }
}

struct ResearchSearchResultsSection: View {
    @Bindable var viewModel: ResearchViewModel
    let searchText: String
    let watchlistSymbols: Set<String>
    var showsWatchlistToggle = true
    let onSelect: (TickerSymbolItem) -> Void

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sortedResults: [TickerSymbolItem] {
        viewModel.results.sorted { lhs, rhs in
            let lhsWatching = watchlistSymbols.contains(lhs.symbol.uppercased())
            let rhsWatching = watchlistSymbols.contains(rhs.symbol.uppercased())
            if lhsWatching != rhsWatching {
                return lhsWatching
            }
            return false
        }
    }

    var body: some View {
        if let error = viewModel.searchError {
            AppInlineBanner(message: error, tone: .error)
        } else if !trimmedQuery.isEmpty,
                  !viewModel.isSearching,
                  viewModel.results.isEmpty {
            AppInlineBanner(
                message: "No symbols found for \"\(trimmedQuery.uppercased())\".",
                tone: .neutral
            )
        } else if !sortedResults.isEmpty {
            AppScreenSection(title: "Results") {
                AppGroupedList {
                    ForEach(Array(sortedResults.prefix(12).enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 0) {
                            Button {
                                onSelect(item)
                            } label: {
                                SymbolSearchRowContent(item: item)
                            }
                            .buttonStyle(.plain)

                            if showsWatchlistToggle {
                                WatchlistToggleButton(symbol: item.symbol, companyName: item.title)
                                    .padding(.trailing, 8)
                            }
                        }

                        if index < min(sortedResults.count, 12) - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }
}

struct SymbolSearchRowContent: View {
    let item: TickerSymbolItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Token.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(Token.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Token.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if let title = item.title, !title.isEmpty {
            return title
        }
        if let assetType = item.assetType {
            return AssetTypeLabel.display(assetType)
        }
        return ""
    }
}
