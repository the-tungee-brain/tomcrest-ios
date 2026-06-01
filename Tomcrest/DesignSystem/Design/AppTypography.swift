import SwiftUI

/// Semantic text styles — Inter, matching web `--font-inter` / `font-sans`.
enum AppTypography {
    static let screenTitle = AppFont.inter(size: 34, weight: .bold, relativeTo: .largeTitle)
    static let sectionTitle = AppFont.inter(size: 17, weight: .semibold, relativeTo: .headline)
    static let cardTitle = AppFont.inter(size: 15, weight: .semibold, relativeTo: .subheadline)
    static let heroMetric = AppFont.inter(size: 34, weight: .bold, relativeTo: .largeTitle)
    static let body = AppFont.inter(size: 17, weight: .regular, relativeTo: .body)
    static let bodySecondary = AppFont.inter(size: 15, weight: .regular, relativeTo: .subheadline)
    static let caption = AppFont.inter(size: 12, weight: .regular, relativeTo: .caption)
    static let captionEmphasis = AppFont.inter(size: 12, weight: .semibold, relativeTo: .caption)
    static let metricLabel = AppFont.inter(size: 12, weight: .medium, relativeTo: .caption)

    /// Web `TomcrestWordmark` — semibold, tight tracking.
    static let brandTitle = AppFont.inter(size: 28, weight: .semibold, relativeTo: .title)

    // MARK: - Mono (web `--font-jetbrains` / `font-mono`)

    static let monoCaption = AppFont.jetbrainsMono(size: 12, weight: .regular, relativeTo: .caption)
    static let monoCaptionSemibold = AppFont.jetbrainsMono(size: 12, weight: .semibold, relativeTo: .caption)
    static let monoCaption2 = AppFont.jetbrainsMono(size: 11, weight: .regular, relativeTo: .caption2)
    static let monoCaption2Medium = AppFont.jetbrainsMono(size: 11, weight: .medium, relativeTo: .caption2)
    static let monoCaption2Semibold = AppFont.jetbrainsMono(size: 11, weight: .semibold, relativeTo: .caption2)
    static let monoSubheadlineMedium = AppFont.jetbrainsMono(size: 15, weight: .medium, relativeTo: .subheadline)
    static let monoSubheadlineSemibold = AppFont.jetbrainsMono(size: 15, weight: .semibold, relativeTo: .subheadline)
    static let monoCardTitle = AppFont.jetbrainsMono(size: 15, weight: .semibold, relativeTo: .subheadline)
    static let monoBody = AppFont.jetbrainsMono(size: 17, weight: .regular, relativeTo: .body)
    static let monoTitle3 = AppFont.jetbrainsMono(size: 20, weight: .semibold, relativeTo: .title3)
    static let monoHeroMetric = AppFont.jetbrainsMono(size: 34, weight: .semibold, relativeTo: .largeTitle)
}
