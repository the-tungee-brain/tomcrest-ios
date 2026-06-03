import SwiftUI

/// Custom main tab bar — supports re-tap-to-root (system `TabView` does not).
struct MainAppTabBar: View {
    @Binding var selectedTab: AppTab
    let onSelect: (AppTab) -> Void

    private struct Item: Identifiable {
        let tab: AppTab
        let title: String
        let image: String
        let selectedImage: String
        var id: AppTab { tab }
    }

    private let items: [Item] = [
        Item(tab: .portfolio, title: "Portfolio", image: "chart.pie", selectedImage: "chart.pie.fill"),
        Item(tab: .movers, title: "Movers", image: "arrow.up.right.circle", selectedImage: "arrow.up.right.circle.fill"),
        Item(tab: .research, title: "Research", image: "magnifyingglass", selectedImage: "magnifyingglass.circle.fill"),
        Item(tab: .settings, title: "Settings", image: "gearshape", selectedImage: "gearshape.fill")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(.top, 6)
        .background {
            Token.surfaceSecondary.opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Divider().overlay(Token.gridLine)
        }
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = selectedTab == item.tab
        return Button {
            onSelect(item.tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? item.selectedImage : item.image)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.monochrome)
                Text(item.title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Layout.minTouchTarget)
            .foregroundStyle(isSelected ? BrandPrimary.color : Token.textTertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
