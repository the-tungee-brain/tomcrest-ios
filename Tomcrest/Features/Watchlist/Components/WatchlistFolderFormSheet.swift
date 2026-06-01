import SwiftUI

struct WatchlistFolderFormSheet: View {
    enum Mode {
        case create
        case edit(WatchlistFolder)
    }

    let mode: Mode
    let onSave: (String, String, WatchlistSwatch.ID, UInt32?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var iconName: String
    @State private var swatchID: WatchlistSwatch.ID
    @State private var accentHex: UInt32?

    private var accentPreview: Color {
        if let hex = accentHex { return Color(hex: hex) }
        return WatchlistPremiumPalette.swatch(id: swatchID).accentColor
    }

    init(mode: Mode, onSave: @escaping (String, String, WatchlistSwatch.ID, UInt32?) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _iconName = State(initialValue: WatchlistFolderIcons.defaultIcon)
            _swatchID = State(initialValue: WatchlistPremiumPalette.swatches[0].id)
            _accentHex = State(initialValue: nil)
        case .edit(let folder):
            _name = State(initialValue: folder.name)
            _iconName = State(initialValue: folder.iconName)
            _swatchID = State(initialValue: folder.swatchID)
            _accentHex = State(initialValue: folder.accentHex)
        }
    }

    private var title: String {
        switch mode {
        case .create: "New folder"
        case .edit: "Customize folder"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        WatchlistFolderIconBadge(symbol: iconName, accent: accentPreview, size: 56, iconScale: .title2)

                        TextField("Folder name", text: $name)
                            .font(AppTypography.cardTitle)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppColors.insetSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    WatchlistFolderIconPicker(selection: $iconName, accent: accentPreview)

                    WatchlistPremiumColorPicker(
                        selectedSwatchID: $swatchID,
                        accentHex: $accentHex,
                        previewIconName: iconName
                    )
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, iconName, swatchID, accentHex)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .appKeyboardDoneToolbar()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

extension WatchlistFolderFormSheet.Mode: Identifiable {
    var id: String {
        switch self {
        case .create: "create"
        case .edit(let folder): folder.id.uuidString
        }
    }
}

struct WatchlistDesignVariantPicker: View {
    @Binding var selection: WatchlistDesignVariant

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WatchlistDesignVariant.allCases) { variant in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                        selection = variant
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(variant.rawValue)
                            .font(.caption.weight(.semibold))
                        Text(variant.subtitle)
                            .font(.caption2)
                            .foregroundStyle(AppColors.tertiaryLabel)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(selection == variant ? AppColors.accentMuted : AppColors.insetSurface)
                    .foregroundStyle(selection == variant ? AppColors.accentHighlight : AppColors.secondaryLabel)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                selection == variant ? AppColors.accent.opacity(0.35) : AppColors.separator,
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(AppColors.secondaryBackground.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.panelBorder, lineWidth: 1)
        }
    }
}
