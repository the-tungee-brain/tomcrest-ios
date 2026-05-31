import SwiftUI

/// Uppercase section label — matches Settings rhythm; one hierarchy level above panel content.
struct AppScreenSectionLabel: View {
    let title: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel)
                .tracking(0.4)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Section label + content with consistent 8pt gap (HIG grouped layout).
struct AppScreenSection<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppScreenSectionLabel(title: title, footnote: footnote)
            content()
        }
    }
}
