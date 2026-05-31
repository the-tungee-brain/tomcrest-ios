import SwiftUI

/// Layout widths aligned with my-pocket `pageLayout.ts`.
enum Layout {
    /// Primary app screens (portfolio, research) — web `max-w-6xl`.
    static let contentMaxWidth: CGFloat = 720
    /// Settings and form-focused screens — web `max-w-3xl`.
    static let narrowContentMaxWidth: CGFloat = 640
    /// Sign-in, waitlist, empty states — web `max-w-lg`.
    static let centeredContentMaxWidth: CGFloat = 420
    static let horizontalPadding: CGFloat = 20
    /// Space between major screen sections (HIG: group related content with clear breaks).
    static let sectionSpacing: CGFloat = 28
    /// Space inside a section between header and content.
    static let itemSpacing: CGFloat = 12
    /// Minimum comfortable tap target (HIG ~44pt).
    static let minTouchTarget: CGFloat = 44
}

private struct AppContentWidth: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func appContentWidth(_ maxWidth: CGFloat = Layout.contentMaxWidth) -> some View {
        modifier(AppContentWidth(maxWidth: maxWidth))
    }

    func appNarrowContentWidth() -> some View {
        appContentWidth(Layout.narrowContentMaxWidth)
    }

    func appCenteredContentWidth() -> some View {
        appContentWidth(Layout.centeredContentMaxWidth)
    }
}
