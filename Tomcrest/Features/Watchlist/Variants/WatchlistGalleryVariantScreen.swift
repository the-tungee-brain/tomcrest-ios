import SwiftUI
import UniformTypeIdentifiers

/// **Variant 1 — Gallery**
/// Premium stacked folder cards. Folder reorder uses native List edit mode (reliable iOS pattern).
struct WatchlistGalleryVariantScreen: View {
    @Bindable var store: WatchlistStore
    @Binding var isEditingFolderOrder: Bool
    var onSelectSymbol: ((String) -> Void)?

    @State private var folderFormMode: WatchlistFolderFormSheet.Mode?
    @State private var targetedDropFolderID: UUID?

    var body: some View {
        Group {
            if isEditingFolderOrder {
                folderReorderList
            } else {
                folderBrowseScroll
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isEditingFolderOrder)
        .sheet(item: $folderFormMode) { mode in
            WatchlistFolderFormSheet(mode: mode) { name, iconName, swatchID, accentHex in
                switch mode {
                case .create:
                    store.addFolder(name: name, iconName: iconName, swatchID: swatchID)
                    if let id = store.folders.last?.id {
                        store.updateFolderStyle(id: id, swatchID: swatchID, accentHex: accentHex)
                    }
                case .edit(let folder):
                    store.renameFolder(id: folder.id, name: name, iconName: iconName)
                    store.updateFolderStyle(id: folder.id, swatchID: swatchID, accentHex: accentHex)
                }
            }
        }
    }

    // MARK: - Browse (default)

    private var folderBrowseScroll: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if !store.pinnedFolders.isEmpty {
                    sectionHeader("Pinned")
                    ForEach(store.pinnedFolders) { folder in
                        folderCard(folder, allowsInteraction: true)
                    }
                }

                if !store.regularFolders.isEmpty {
                    sectionHeader(store.pinnedFolders.isEmpty ? "Folders" : "All folders")
                    ForEach(store.regularFolders) { folder in
                        folderCard(folder, allowsInteraction: true)
                    }
                }
            }
            .id(store.folderSortMode)
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
        }
    }

    // MARK: - Edit / reorder

    private var folderReorderList: some View {
        List {
            if !store.pinnedFolders.isEmpty {
                Section {
                    ForEach(store.pinnedFolders) { folder in
                        folderEditRow(folder)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 8))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        store.reorderFolders(inPinnedSection: true, from: source, to: destination)
                    }
                } header: {
                    sectionHeader("Pinned")
                }
            }

            if !store.regularFolders.isEmpty {
                Section {
                    ForEach(store.regularFolders) { folder in
                        folderEditRow(folder)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 8))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        store.reorderFolders(inPinnedSection: false, from: source, to: destination)
                    }
                } header: {
                    sectionHeader(store.pinnedFolders.isEmpty ? "Folders" : "All folders")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
        .padding(.bottom, 96)
        .accessibilityLabel("Reorder folders")
    }

    @ViewBuilder
    private func folderEditRow(_ folder: WatchlistFolder) -> some View {
        let swatch = store.swatch(for: folder)
        let accent = store.accentColor(for: folder)
        let performance = store.folderDayChange(folder)

        folderHeader(folder, accent: accent, performance: performance, allowsCollapseTap: false)
            .watchlistFolderChrome(swatch: swatch, accent: accent)
            .accessibilityHint("Drag to reorder")
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(AppColors.tertiaryLabel)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func folderCard(_ folder: WatchlistFolder, allowsInteraction: Bool) -> some View {
        let swatch = store.swatch(for: folder)
        let accent = store.accentColor(for: folder)
        let performance = store.folderDayChange(folder)
        let isDropTarget = targetedDropFolderID == folder.id

        VStack(alignment: .leading, spacing: 0) {
            folderHeader(
                folder,
                accent: accent,
                performance: performance,
                allowsCollapseTap: allowsInteraction
            )
            .zIndex(1)
            .contextMenu {
                folderContextMenu(folder)
            }

            WatchlistFolderExpandableContent(isCollapsed: folder.isCollapsed) {
                VStack(spacing: 8) {
                    ForEach(folder.symbols) { symbol in
                        symbolRow(symbol, folderID: folder.id, accent: accent)
                    }

                    if folder.symbols.isEmpty {
                        Text("Drag symbols here or add from search later.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
        .watchlistFolderChrome(swatch: swatch, accent: accent, isTargeted: isDropTarget)
        .dropDestination(for: WatchlistSymbolDragPayload.self) { items, _ in
            guard allowsInteraction, let payload = items.first else { return false }
            store.moveSymbol(payload, to: folder.id)
            targetedDropFolderID = nil
            return true
        } isTargeted: { targeted in
            targetedDropFolderID = targeted ? folder.id : nil
        }
    }

    @ViewBuilder
    private func folderHeader(
        _ folder: WatchlistFolder,
        accent: Color,
        performance: (value: Double, percent: Double),
        allowsCollapseTap: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if allowsCollapseTap {
                    Button {
                        store.toggleCollapse(folderID: folder.id)
                    } label: {
                        headerMainContent(
                            folder: folder,
                            accent: accent,
                            performance: performance,
                            showChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    headerMainContent(
                        folder: folder,
                        accent: accent,
                        performance: performance,
                        showChevron: false
                    )
                }
            }

            if allowsCollapseTap {
                Button {
                    folderFormMode = .edit(folder)
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func headerMainContent(
        folder: WatchlistFolder,
        accent: Color,
        performance: (value: Double, percent: Double),
        showChevron: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            WatchlistFolderIconBadge(symbol: folder.iconName, accent: accent)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(folder.name)
                        .font(AppTypography.sectionTitle)
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
                        WatchlistFolderPerformanceSummary(change: performance.value, percent: performance.percent)
                    }
                }
            }

            Spacer(minLength: 0)

            if showChevron {
                Image(systemName: folder.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(width: 32, height: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func symbolRow(_ symbol: WatchlistSymbol, folderID: UUID, accent: Color) -> some View {
        let payload = WatchlistSymbolDragPayload(symbolID: symbol.id, sourceFolderID: folderID)
        let isDragging = store.activeDragSymbol == payload

        WatchlistSymbolRow(
            symbol: symbol,
            folderAccent: accent,
            isDragging: isDragging
        ) {
            onSelectSymbol?(symbol.ticker)
        }
        .draggable(payload) {
            WatchlistSymbolRow(symbol: symbol, folderAccent: accent)
                .frame(width: 320)
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: WatchlistFolder) -> some View {
        if folder.isPinned {
            Button {
                store.togglePin(folderID: folder.id)
            } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        }

        Button {
            folderFormMode = .edit(folder)
        } label: {
            Label("Customize", systemImage: "paintpalette")
        }

        if !folder.isPinned {
            Button {
                store.togglePin(folderID: folder.id)
            } label: {
                Label("Pin to top", systemImage: "pin")
            }
        }

        Button(role: .destructive) {
            store.deleteFolder(id: folder.id)
        } label: {
            Label("Delete folder", systemImage: "trash")
        }
    }
}
