import Foundation

/// Push destinations for portfolio detail flows (kept off the main dashboard).
enum PortfolioDestination: Hashable {
    case today
    case holdings
    case news
    case activity
}
