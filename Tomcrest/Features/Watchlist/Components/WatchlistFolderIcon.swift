import SwiftUI

enum WatchlistFolderIcons {
    static let defaultIcon = "folder.fill"

    /// Curated SF Symbols — fintech-friendly, reads well at small sizes.
    static let catalog: [(symbol: String, label: String)] = [
        ("folder.fill", "Folder"),
        ("star.fill", "Star"),
        ("chart.line.uptrend.xyaxis", "Growth"),
        ("chart.pie.fill", "Allocation"),
        ("dollarsign.circle.fill", "Income"),
        ("banknote.fill", "Dividends"),
        ("building.columns.fill", "Index"),
        ("globe.americas.fill", "Global"),
        ("bolt.fill", "Momentum"),
        ("flame.fill", "Hot"),
        ("eye.fill", "Watch"),
        ("clock.fill", "Later"),
        ("leaf.fill", "ESG"),
        ("shield.fill", "Defensive"),
        ("sparkles", "Ideas"),
        ("target", "Goals"),
        ("briefcase.fill", "Portfolio"),
        ("bitcoinsign.circle.fill", "Crypto"),
        ("rocket.fill", "Rocket"),
        ("square.stack.3d.up.fill", "Composition"),
        ("heart.fill", "Heart"),
    ]

    static func label(for symbol: String) -> String {
        catalog.first { $0.symbol == symbol }?.label ?? "Folder"
    }
}

struct WatchlistFolderIconBadge: View {
    let symbol: String
    var accent: Color
    var size: CGFloat = 46
    var iconScale: Font = .title2

    var body: some View {
        Image(systemName: symbol)
            .font(iconScale.weight(.semibold))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(accent.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(accent.opacity(0.32), lineWidth: 1)
            }
            .accessibilityLabel(WatchlistFolderIcons.label(for: symbol))
    }
}

struct WatchlistFolderIconPicker: View {
    @Binding var selection: String
    var accent: Color = AppColors.accentHighlight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon")
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.secondaryLabel)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WatchlistFolderIcons.catalog, id: \.symbol) { item in
                        iconButton(symbol: item.symbol, label: item.label)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private func iconButton(symbol: String, label: String) -> some View {
        let isSelected = selection == symbol

        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selection = symbol
            }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? accent : AppColors.secondaryLabel)
                .frame(width: 48, height: 48)
                .background(isSelected ? accent.opacity(0.18) : AppColors.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected ? accent.opacity(0.45) : AppColors.separator,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
