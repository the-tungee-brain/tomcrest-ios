import SwiftUI

/// Horizontal tab bar — text-only chips, no icon noise; matches AppChip styling app-wide.
struct ResearchTabBar: View {
    let tabs: [ResearchTab]
    @Binding var selection: ResearchTab
    var assetType: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    let label = tab == .fundamentals ? tab.fundamentalsLabel(for: assetType) : tab.label
                    AppChip(title: label, isSelected: selection == tab) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = tab
                        }
                    }
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Research sections")
    }
}
