import SwiftUI

struct WatchlistPremiumColorPicker: View {
    @Binding var selectedSwatchID: WatchlistSwatch.ID
    @Binding var accentHex: UInt32?
    var showsAccentRow = true
    var previewIconName: String = WatchlistFolderIcons.defaultIcon

    @State private var accentSelection: WatchlistSwatch.ID?

    private let swatchTileWidth: CGFloat = 72
    private let swatchLabelHeight: CGFloat = 30

    private var selectedSwatch: WatchlistSwatch {
        WatchlistPremiumPalette.swatch(id: selectedSwatchID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(WatchlistFolderCompositionSection.allCases, id: \.self) { section in
                let sectionSwatches = section.swatches
                if !sectionSwatches.isEmpty {
                    swatchSection(title: section.rawValue, swatches: sectionSwatches)
                }
            }

            if showsAccentRow {
                Text("Icon accent")
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .textCase(.uppercase)
                    .padding(.top, 4)

                AppHorizontalScrollRow {
                    HStack(spacing: 10) {
                        accentChip(label: "Auto", color: selectedSwatch.accentColor, isSelected: accentHex == nil) {
                            accentHex = nil
                            accentSelection = nil
                        }

                        ForEach(WatchlistPremiumPalette.swatches) { swatch in
                            accentChip(
                                label: swatch.name,
                                color: swatch.accentColor,
                                isSelected: accentHex == swatch.accent
                            ) {
                                accentHex = swatch.accent
                                accentSelection = swatch.id
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            previewCard
        }
    }

    @ViewBuilder
    private func swatchSection(title: String, swatches: [WatchlistSwatch]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            AppHorizontalScrollRow {
                HStack(spacing: 10) {
                    ForEach(swatches) { swatch in
                        swatchButton(swatch)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var previewCard: some View {
        HStack(spacing: 12) {
            WatchlistFolderIconBadge(symbol: previewIconName, accent: accentColor, size: 44, iconScale: .body)

            VStack(alignment: .leading, spacing: 2) {
                Text("Preview folder")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                Text(selectedSwatch.name)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Spacer()
        }
        .padding(14)
        .watchlistFolderChrome(swatch: selectedSwatch, accent: accentColor)
    }

    private var accentColor: Color {
        if let hex = accentHex { return Color(hex: hex) }
        return selectedSwatch.accentColor
    }

    @ViewBuilder
    private func swatchButton(_ swatch: WatchlistSwatch) -> some View {
        let isSelected = swatch.id == selectedSwatchID

        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selectedSwatchID = swatch.id
                if accentSelection != nil, accentHex != nil {
                    accentHex = swatch.accent
                }
            }
        } label: {
            VStack(spacing: 6) {
                WatchlistSwatchPreviewFill(swatch: swatch)
                    .frame(width: swatchTileWidth, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? swatch.accentColor : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(swatch.accentColor)
                            .frame(width: 10, height: 10)
                            .padding(6)
                    }

                Text(swatch.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? AppColors.label : AppColors.tertiaryLabel)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: swatchTileWidth, height: swatchLabelHeight, alignment: .top)
            }
            .frame(width: swatchTileWidth)
        }
        .buttonStyle(.plain)
    }

    private func accentChip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? AppColors.label : AppColors.secondaryLabel)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.18) : AppColors.insetSurface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.45) : AppColors.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
