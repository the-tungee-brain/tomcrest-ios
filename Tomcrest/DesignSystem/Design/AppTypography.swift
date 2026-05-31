import SwiftUI

/// System text styles — one scale used across the app.
enum AppTypography {
    static let screenTitle = Font.largeTitle.bold()
    static let sectionTitle = Font.headline.weight(.semibold)
    static let cardTitle = Font.subheadline.weight(.semibold)
    static let heroMetric = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let body = Font.body
    static let bodySecondary = Font.subheadline
    static let caption = Font.caption
    static let captionEmphasis = Font.caption.weight(.semibold)
    static let metricLabel = Font.caption.weight(.medium)
}
