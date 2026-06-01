import Foundation

enum OnboardingStorage {
    private static let strategyDismissedKey = "tomcrest-strategy-onboarding-dismissed"
    private static let portfolioDismissedKey = "tomcrest-portfolio-onboarding-dismissed"
    private static let researchDismissedKey = "tomcrest-research-onboarding-dismissed"
    private static let strategyJourneyCollapsedKey = "tomcrest-strategy-journey-collapsed"
    private static let watchlistHintDismissedKey = "tomcrest-watchlist-hint-dismissed"

    static func isStrategyOnboardingDismissed() -> Bool {
        UserDefaults.standard.bool(forKey: strategyDismissedKey)
    }

    static func dismissStrategyOnboarding() {
        UserDefaults.standard.set(true, forKey: strategyDismissedKey)
    }

    static func isPortfolioOnboardingDismissed() -> Bool {
        UserDefaults.standard.bool(forKey: portfolioDismissedKey)
    }

    static func dismissPortfolioOnboarding() {
        UserDefaults.standard.set(true, forKey: portfolioDismissedKey)
    }

    static func isResearchOnboardingDismissed() -> Bool {
        UserDefaults.standard.bool(forKey: researchDismissedKey)
    }

    static func dismissResearchOnboarding() {
        UserDefaults.standard.set(true, forKey: researchDismissedKey)
    }

    static func isStrategyJourneyCollapsed() -> Bool {
        UserDefaults.standard.bool(forKey: strategyJourneyCollapsedKey)
    }

    static func setStrategyJourneyCollapsed(_ collapsed: Bool) {
        UserDefaults.standard.set(collapsed, forKey: strategyJourneyCollapsedKey)
    }

    private static let portfolioWatchlistCollapsedKey = "tomcrest-portfolio-watchlist-collapsed"

    /// Defaults to expanded on first launch.
    static func isPortfolioWatchlistCollapsed() -> Bool {
        guard UserDefaults.standard.object(forKey: portfolioWatchlistCollapsedKey) != nil else {
            return false
        }
        return UserDefaults.standard.bool(forKey: portfolioWatchlistCollapsedKey)
    }

    static func setPortfolioWatchlistCollapsed(_ collapsed: Bool) {
        UserDefaults.standard.set(collapsed, forKey: portfolioWatchlistCollapsedKey)
    }

    static func isWatchlistHintDismissed() -> Bool {
        UserDefaults.standard.bool(forKey: watchlistHintDismissedKey)
    }

    static func dismissWatchlistHint() {
        UserDefaults.standard.set(true, forKey: watchlistHintDismissedKey)
    }
}

enum SettingsFocus: Equatable {
    case strategy
}
