import SwiftUI

struct PortfolioWatchlistPanel: View {
    @Environment(WatchlistStore.self) private var watchlistStore
    let onSelect: (String) -> Void

    @State private var isExpanded = !OnboardingStorage.isPortfolioWatchlistCollapsed()
    @State private var collapsedFolderIDs: Set<UUID> = []
    @State private var folderFormMode: WatchlistFolderFormSheet.Mode?

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
            await watchlistStore.refreshQuotesIfNeeded()
        }
        .sheet(item: $folderFormMode) { mode in
            WatchlistFolderFormSheet(mode: mode) { name, iconName, swatchID, accentHex in
                if case .edit(let folder) = mode {
                    watchlistStore.renameFolder(id: folder.id, name: name, iconName: iconName)
                    watchlistStore.updateFolderStyle(id: folder.id, swatchID: swatchID, accentHex: accentHex)
                }
            }
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
        let isFolderCollapsed = collapsedFolderIDs.contains(folder.id)

        VStack(alignment: .leading, spacing: 0) {
            folderHeader(folder, accent: accent, isCollapsed: isFolderCollapsed)
                .zIndex(1)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        toggleFolderCollapse(folder.id)
                    }
                }
                .contextMenu {
                    Button {
                        folderFormMode = .edit(folder)
                    } label: {
                        Label("Customize", systemImage: "paintpalette")
                    }

                    if folder.isPinned {
                        Button {
                            watchlistStore.togglePin(folderID: folder.id)
                        } label: {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                    } else {
                        Button {
                            watchlistStore.togglePin(folderID: folder.id)
                        } label: {
                            Label("Pin to top", systemImage: "pin")
                        }
                    }
                }

            WatchlistFolderExpandableContent(isCollapsed: isFolderCollapsed) {
                VStack(spacing: 8) {
                    if folder.symbols.isEmpty {
                        Text("No symbols in this folder yet.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    } else {
                        LazyVStack(spacing: 8) {
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
                }
            }
        }
        .watchlistFolderChrome(swatch: swatch, accent: accent, accentHex: folder.accentHex)
    }

    @ViewBuilder
    private func folderHeader(
        _ folder: WatchlistFolder,
        accent: Color,
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

                    WatchlistFolderDayChangeView(folder: folder)
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
