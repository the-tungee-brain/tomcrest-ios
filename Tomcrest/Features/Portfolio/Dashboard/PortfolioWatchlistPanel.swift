import SwiftUI

struct PortfolioWatchlistPanel: View {
    @Environment(WatchlistStore.self) private var watchlistStore
    let onSelect: (String) -> Void

    @State private var isExpanded = !OnboardingStorage.isPortfolioWatchlistCollapsed()
    @State private var collapsedFolderIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader

            if isExpanded {
                if watchlistStore.sortedFolders.isEmpty {
                    emptyPanel
                } else {
                    VStack(spacing: 12) {
                        if !watchlistStore.pinnedFolders.isEmpty, !watchlistStore.regularFolders.isEmpty {
                            folderGroup(title: "Pinned", folders: watchlistStore.pinnedFolders)
                            folderGroup(title: "Folders", folders: watchlistStore.regularFolders)
                        } else {
                            folderGroup(title: nil, folders: watchlistStore.sortedFolders)
                        }
                    }
                }
            }
        }
        .task(id: isExpanded) {
            guard isExpanded else { return }
            await watchlistStore.ensureLoaded()
            await watchlistStore.refreshQuotes()
        }
    }

    private var sectionHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
                OnboardingStorage.setPortfolioWatchlistCollapsed(!isExpanded)
            }
        } label: {
            HStack(spacing: 8) {
                Text("Watchlist")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)

                if watchlistStore.hasSymbols {
                    Text("\(watchlistStore.allTickers.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyPanel: some View {
        PortfolioQuickLinkRow(
            icon: "star",
            iconTint: AppColors.secondaryLabel,
            title: "No saved symbols",
            subtitle: "Star tickers in Research to track them here"
        )
        .allowsHitTesting(false)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func folderGroup(title: String?, folders: [WatchlistFolder]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
            }

            ForEach(folders) { folder in
                folderCard(folder)
            }
        }
    }

    @ViewBuilder
    private func folderCard(_ folder: WatchlistFolder) -> some View {
        let swatch = watchlistStore.swatch(for: folder)
        let accent = watchlistStore.accentColor(for: folder)
        let performance = watchlistStore.folderDayChange(folder)
        let isFolderCollapsed = collapsedFolderIDs.contains(folder.id)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toggleFolderCollapse(folder.id)
                }
            } label: {
                folderHeader(folder, accent: accent, performance: performance, isCollapsed: isFolderCollapsed)
            }
            .buttonStyle(.plain)

            if !isFolderCollapsed {
                VStack(spacing: 8) {
                    if folder.symbols.isEmpty {
                        Text("No symbols in this folder yet.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(folder.symbols) { symbol in
                            WatchlistSymbolRow(
                                symbol: symbol,
                                folderAccent: accent
                            ) {
                                onSelect(symbol.ticker)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .watchlistFolderChrome(swatch: swatch, accent: accent)
    }

    @ViewBuilder
    private func folderHeader(
        _ folder: WatchlistFolder,
        accent: Color,
        performance: (value: Double, percent: Double),
        isCollapsed: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            WatchlistFolderIconBadge(symbol: folder.iconName, accent: accent, size: 40, iconScale: .body)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(folder.name)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.label)

                    if folder.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                    }
                }

                HStack(spacing: 8) {
                    Text("\(folder.symbols.count) symbols")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)

                    if !folder.symbols.isEmpty {
                        WatchlistFolderPerformanceSummary(
                            change: performance.value,
                            percent: performance.percent
                        )
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .rotationEffect(.degrees(isCollapsed ? 0 : 180))
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private func toggleFolderCollapse(_ folderID: UUID) {
        if collapsedFolderIDs.contains(folderID) {
            collapsedFolderIDs.remove(folderID)
        } else {
            collapsedFolderIDs.insert(folderID)
        }
    }
}
