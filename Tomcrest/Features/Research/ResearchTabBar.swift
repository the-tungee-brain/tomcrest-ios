import SwiftUI

/// Horizontal section tabs for symbol research — chip row when tab count varies by asset type.
struct ResearchTabBar<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    var assetType: String?
    private let label: (Tab, String?) -> String

    init(
        tabs: [ResearchTab],
        selection: Binding<ResearchTab>,
        assetType: String? = nil
    ) where Tab == ResearchTab {
        self.tabs = tabs
        self._selection = selection
        self.assetType = assetType
        self.label = { tab, assetType in
            tab == .metrics ? tab.metricsLabel(for: assetType) : tab.label
        }
    }

    init(
        tabs: [ResearchPrimaryTab],
        selection: Binding<ResearchPrimaryTab>,
        assetType: String? = nil
    ) where Tab == ResearchPrimaryTab {
        self.tabs = tabs
        self._selection = selection
        self.assetType = assetType
        self.label = { tab, _ in tab.label }
    }

    var body: some View {
        AppChipRow(tabs: tabs, selection: $selection) { tab in
            label(tab, assetType)
        }
        .accessibilityLabel("Research sections")
    }
}
