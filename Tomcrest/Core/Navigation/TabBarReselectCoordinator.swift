import Foundation

/// Increments when the user taps the already-selected main tab (pop-to-root signal).
@MainActor
@Observable
final class TabBarReselectCoordinator {
    private(set) var portfolioReselectCount = 0
    private(set) var moversReselectCount = 0
    private(set) var researchReselectCount = 0
    private(set) var settingsReselectCount = 0
    private(set) var reinstallToken = 0

    /// Bumps when tab selection changes so the tab bar delegate can be re-attached.
    func scheduleReinstall() {
        reinstallToken += 1
    }

    func noteReselect(_ tab: AppTab) {
        switch tab {
        case .portfolio:
            portfolioReselectCount += 1
        case .movers:
            moversReselectCount += 1
        case .research:
            researchReselectCount += 1
        case .settings:
            settingsReselectCount += 1
        }
    }
}
