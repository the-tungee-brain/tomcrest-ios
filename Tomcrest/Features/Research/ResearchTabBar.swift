import SwiftUI

/// Horizontal section tabs for symbol research — chip row when tab count varies by asset type.
struct ResearchTabBar: View {
    let tabs: [ResearchTab]
    @Binding var selection: ResearchTab
    var assetType: String?

    var body: some View {
        AppChipRow(tabs: tabs, selection: $selection) { tab in
            tab == .metrics ? tab.metricsLabel(for: assetType) : tab.label
        }
        .accessibilityLabel("Research sections")
    }
}
