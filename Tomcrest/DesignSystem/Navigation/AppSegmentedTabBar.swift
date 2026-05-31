import SwiftUI

/// Apple-style segmented control for in-screen section tabs (Portfolio, Research symbol).
struct AppSegmentedTabBar<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let label: (Tab) -> String
    var badge: (Tab) -> Int = { _ in 0 }
    var accessibilityLabel = "Sections"

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                segmentButton(for: tab)
            }
        }
        .padding(4)
        .background(Token.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Token.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func segmentButton(for tab: Tab) -> some View {
        let isSelected = selection == tab
        let badgeCount = badge(tab)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 5) {
                Text(label(tab))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Token.primaryMuted : Token.surfaceFillSecondary)
                        .foregroundStyle(isSelected ? Token.primaryHighlight : Token.textSecondary)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? Token.primaryHighlight : Token.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Token.primaryMuted : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Compact horizontal chip row — search examples, filters where segments don't fit.
struct AppChipRow<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let label: (Tab) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs, id: \.self) { tab in
                    AppChip(title: label(tab), isSelected: selection == tab) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = tab
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
    }
}
