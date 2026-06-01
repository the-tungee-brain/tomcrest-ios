import SwiftUI

/// Pick folder(s) when starring a symbol from Research.
struct WatchlistSaveSymbolSheet: View {
    @Environment(WatchlistStore.self) private var watchlistStore
    @Environment(\.dismiss) private var dismiss

    let symbol: String
    var companyName: String?

    @State private var folderFormMode: WatchlistFolderFormSheet.Mode?

    private var ticker: String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var displayName: String {
        companyName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? ticker
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if watchlistStore.sortedFolders.isEmpty {
                        emptyState
                    } else {
                        folderList
                    }

                    newFolderButton
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle("Save to folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $folderFormMode) { mode in
            WatchlistFolderFormSheet(mode: mode) { name, iconName, swatchID, accentHex in
                switch mode {
                case .create:
                    watchlistStore.addFolder(name: name, iconName: iconName, swatchID: swatchID)
                    if let folderID = watchlistStore.folders.last?.id {
                        watchlistStore.updateFolderStyle(id: folderID, swatchID: swatchID, accentHex: accentHex)
                        watchlistStore.addSymbol(ticker, companyName: displayName, toFolderID: folderID)
                    }
                case .edit(let folder):
                    watchlistStore.renameFolder(id: folder.id, name: name, iconName: iconName)
                    watchlistStore.updateFolderStyle(id: folder.id, swatchID: swatchID, accentHex: accentHex)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                Text(displayName)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppColors.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No folders yet")
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.label)
            Text("Create a folder to start tracking \(ticker).")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appPanel(subtle: true)
    }

    private var folderList: some View {
        VStack(spacing: 10) {
            ForEach(watchlistStore.sortedFolders) { folder in
                folderRow(folder)
            }
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: WatchlistFolder) -> some View {
        let accent = watchlistStore.accentColor(for: folder)
        let isSelected = watchlistStore.isSymbol(ticker, inFolderID: folder.id)

        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    if isSelected {
                        watchlistStore.removeSymbol(ticker, fromFolderID: folder.id)
                    } else {
                        watchlistStore.addSymbol(ticker, companyName: displayName, toFolderID: folder.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    WatchlistFolderIconBadge(symbol: folder.iconName, accent: accent, size: 40, iconScale: .body)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColors.label)
                        Text("\(folder.symbols.count) symbols")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? accent : AppColors.tertiaryLabel)
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                folderFormMode = .edit(folder)
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Customize \(folder.name)")
            .padding(.trailing, 4)
        }
        .background(isSelected ? accent.opacity(0.12) : AppColors.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? accent.opacity(0.35) : AppColors.separator, lineWidth: 1)
        }
    }

    private var newFolderButton: some View {
        Button {
            folderFormMode = .create
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.badge.plus")
                    .font(.body.weight(.semibold))
                Text("Create new folder")
                    .font(AppTypography.cardTitle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
            .foregroundStyle(AppColors.accentHighlight)
            .padding(16)
            .background(AppColors.accentMuted.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColors.accent.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
