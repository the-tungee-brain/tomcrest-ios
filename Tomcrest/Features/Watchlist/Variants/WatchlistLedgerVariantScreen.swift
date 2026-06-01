import SwiftUI

/// **Variant 2 — Ledger**
/// Grouped list with sticky section headers, horizontal pinned chips, and swipe-friendly folder chrome.
struct WatchlistLedgerVariantScreen: View {
    @Bindable var store: WatchlistStore
    var onSelectSymbol: ((String) -> Void)?

    @State private var folderFormMode: WatchlistFolderFormSheet.Mode?
    @State private var editingFolderID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !store.pinnedFolders.isEmpty {
                    pinnedStrip
                }

                ForEach(store.sortedFolders) { folder in
                    ledgerSection(folder)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
        }
        .id(store.folderSortMode)
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

    private var pinnedStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pinned")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.pinnedFolders) { folder in
                        pinnedChip(folder)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pinnedChip(_ folder: WatchlistFolder) -> some View {
        let accent = store.accentColor(for: folder)
        let isExpanded = !folder.isCollapsed

        Button {
            store.toggleCollapse(folderID: folder.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: folder.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Text(folder.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(folder.symbols.count)")
                    .font(AppTypography.monoCaption2Semibold)
                    .foregroundStyle(accent)
            }
            .foregroundStyle(isExpanded ? AppColors.label : AppColors.secondaryLabel)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                WatchlistFolderBackground(swatch: store.swatch(for: folder), accentOverride: accent)
                    .opacity(isExpanded ? 0.95 : 0.55)
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(accent.opacity(isExpanded ? 0.45 : 0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func ledgerSection(_ folder: WatchlistFolder) -> some View {
        let swatch = store.swatch(for: folder)
        let accent = store.accentColor(for: folder)
        let isExpanded = !folder.isCollapsed
        let isEditing = editingFolderID == folder.id

        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(folder, swatch: swatch, accent: accent, isExpanded: isExpanded)

            if isEditing {
                WatchlistPremiumColorPicker(
                    selectedSwatchID: bindingSwatchID(for: folder),
                    accentHex: bindingAccentHex(for: folder),
                    showsAccentRow: true,
                    previewIconName: folder.iconName
                )
                .padding(14)
                .background(AppColors.insetSurface)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(folder.symbols.enumerated()), id: \.element.id) { index, symbol in
                        WatchlistSymbolRow(symbol: symbol, style: .plain) {
                            onSelectSymbol?(symbol.ticker)
                        }
                        .draggable(WatchlistSymbolDragPayload(symbolID: symbol.id, sourceFolderID: folder.id))

                        if index < folder.symbols.count - 1 {
                            Divider()
                                .overlay(AppColors.separator.opacity(0.5))
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(AppColors.secondaryBackground.opacity(0.55))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 1)
        }
        .dropDestination(for: WatchlistSymbolDragPayload.self) { items, _ in
            guard let payload = items.first else { return false }
            store.moveSymbol(payload, to: folder.id)
            if folder.isCollapsed {
                store.toggleCollapse(folderID: folder.id)
            }
            return true
        }
        .contextMenu {
            Button {
                folderFormMode = .edit(folder)
            } label: {
                Label("Rename & colors", systemImage: "pencil")
            }

            Button {
                store.togglePin(folderID: folder.id)
            } label: {
                Label(folder.isPinned ? "Unpin" : "Pin", systemImage: folder.isPinned ? "pin.slash" : "pin")
            }

            Button(role: .destructive) {
                store.deleteFolder(id: folder.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(
        _ folder: WatchlistFolder,
        swatch: WatchlistSwatch,
        accent: Color,
        isExpanded: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                store.toggleCollapse(folderID: folder.id)
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(accent)
                        .frame(width: 4, height: 36)

                    WatchlistFolderIconBadge(symbol: folder.iconName, accent: accent, size: 40, iconScale: .body)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColors.label)

                        HStack(spacing: 6) {
                            Text("\(folder.symbols.count) symbols")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.tertiaryLabel)
                                .fixedSize(horizontal: true, vertical: false)

                            WatchlistFolderDayChangeView(folder: folder)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.secondaryLabel)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 32, height: 32)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    editingFolderID = editingFolderID == folder.id ? nil : folder.id
                }
            } label: {
                Image(systemName: "paintpalette")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(editingFolderID == folder.id ? accent : AppColors.tertiaryLabel)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            WatchlistFolderBackground(swatch: swatch, accentOverride: accent)
                .opacity(0.72)
        }
    }

    private func bindingSwatchID(for folder: WatchlistFolder) -> Binding<WatchlistSwatch.ID> {
        Binding(
            get: { store.folder(id: folder.id)?.swatchID ?? folder.swatchID },
            set: { newValue in
                store.updateFolderStyle(id: folder.id, swatchID: newValue, accentHex: store.folder(id: folder.id)?.accentHex)
            }
        )
    }

    private func bindingAccentHex(for folder: WatchlistFolder) -> Binding<UInt32?> {
        Binding(
            get: { store.folder(id: folder.id)?.accentHex },
            set: { newValue in
                let swatchID = store.folder(id: folder.id)?.swatchID ?? folder.swatchID
                store.updateFolderStyle(id: folder.id, swatchID: swatchID, accentHex: newValue)
            }
        )
    }
}
