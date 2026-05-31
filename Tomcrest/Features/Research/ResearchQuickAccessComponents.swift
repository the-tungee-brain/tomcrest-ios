import SwiftUI

struct WatchlistToggleButton: View {
    @Environment(ResearchSymbolBookmarks.self) private var bookmarks
    let symbol: String
    var iconOnly = true

    private var watching: Bool {
        bookmarks.isWatchlisted(symbol)
    }

    var body: some View {
        Button {
            bookmarks.toggleWatchlist(symbol)
        } label: {
            if iconOnly {
                Image(systemName: watching ? "star.fill" : "star")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(watching ? AppColors.accentHighlight : AppColors.secondaryLabel)
                    .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: watching ? "star.fill" : "star")
                        .font(.caption.weight(.semibold))
                    Text(watching ? "Watching" : "Add to watchlist")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(watching ? AppColors.accentHighlight : AppColors.label)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(watching ? AppColors.accentMuted : AppColors.background)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(AppColors.separator, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            watching
                ? "Remove \(symbol.uppercased()) from watchlist"
                : "Add \(symbol.uppercased()) to watchlist"
        )
    }
}

struct ResearchWatchlistSection: View {
    let symbols: [String]
    let onSelect: (String) -> Void

    var body: some View {
        AppScreenSection(title: "Your watchlist") {
            ResearchSymbolChipRow(symbols: symbols, style: .watchlist, onSelect: onSelect)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Button {
                        onSelect(symbol)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: style == .watchlist ? "star.fill" : "clock")
                                .font(.caption2.weight(.semibold))
                            Text(symbol)
                                .font(.caption.weight(.semibold).monospaced())
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
                                : AppColors.background
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
        }
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(symbols, id: \.self) { symbol in
                                playbookSymbolChip(symbol: symbol, strategyId: strategyId)
                            }
                        }
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
                        .font(.caption.weight(.semibold).monospaced())
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
            .background(needsAttention ? AppColors.accentMuted.opacity(0.35) : AppColors.background)
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
