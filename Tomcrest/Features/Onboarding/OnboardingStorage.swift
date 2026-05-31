import Foundation

enum OnboardingStorage {
    private static let strategyDismissedKey = "tomcrest-strategy-onboarding-dismissed"
    private static let portfolioDismissedKey = "tomcrest-portfolio-onboarding-dismissed"
    private static let researchDismissedKey = "tomcrest-research-onboarding-dismissed"

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
}

enum SettingsFocus: Equatable {
    case strategy
}
