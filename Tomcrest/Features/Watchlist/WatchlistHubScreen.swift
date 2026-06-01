import SwiftUI

/// Folder-based watchlist synced to the Tomcrest API (Gallery layout).
struct WatchlistHubScreen: View {
    @Environment(WatchlistStore.self) private var watchlistStore
    @State private var folderFormMode: WatchlistFolderFormSheet.Mode?
    @State private var isEditingFolderOrder = false

    var onSelectSymbol: ((String) -> Void)?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if let errorMessage = watchlistStore.errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                WatchlistGalleryVariantScreen(
                    store: watchlistStore,
                    isEditingFolderOrder: $isEditingFolderOrder,
                    onSelectSymbol: onSelectSymbol
                )
                    .overlay {
                        if watchlistStore.isLoading {
                            ProgressView("Loading watchlist…")
                                .font(AppTypography.caption)
                                .padding(16)
                                .background(AppColors.secondaryBackground.opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
            }

            newFolderButton
        }
        .navigationTitle("Watchlist")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if isEditingFolderOrder {
                        Button("Done") {
                            isEditingFolderOrder = false
                        }
                        .font(AppTypography.cardTitle)
                    } else if !watchlistStore.folders.isEmpty {
                        Button("Reorder") {
                            watchlistStore.folderSortMode = .custom
                            isEditingFolderOrder = true
                        }
                        .font(AppTypography.cardTitle)
                    }

                    Menu {
                        Picker("Sort folders", selection: Binding(
                            get: { watchlistStore.folderSortMode },
                            set: { watchlistStore.folderSortMode = $0 }
                        )) {
                            ForEach(WatchlistFolderSortMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: mode.systemImage)
                                    .tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(isEditingFolderOrder)
                    .accessibilityLabel("Sort folders")
                }
            }
        }
        .onChange(of: watchlistStore.folderSortMode) { _, _ in
            if isEditingFolderOrder {
                isEditingFolderOrder = false
            }
        }
        .appPushedScreenCanvas()
        .refreshable {
            guard !isEditingFolderOrder else { return }
            await watchlistStore.refreshQuotesIfNeeded(force: true)
        }
        .sheet(item: $folderFormMode) { mode in
            WatchlistFolderFormSheet(mode: mode) { name, iconName, swatchID, accentHex in
                watchlistStore.addFolder(name: name, iconName: iconName, swatchID: swatchID)
                if let id = watchlistStore.folders.last?.id {
                    watchlistStore.updateFolderStyle(id: id, swatchID: swatchID, accentHex: accentHex)
                }
            }
        }
    }

    private var newFolderButton: some View {
        Button {
            folderFormMode = .create
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.body.weight(.semibold))
                Text("New folder")
                    .font(AppTypography.cardTitle)
            }
            .foregroundStyle(AppColors.onAccent)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(AppColors.accent)
            .clipShape(Capsule())
            .shadow(color: AppColors.accent.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 20)
    }
}

#Preview {
    NavigationStack {
        WatchlistHubScreen()
            .environment(WatchlistStore())
            .environment(AuthSession())
    }
    .preferredColorScheme(.dark)
}
