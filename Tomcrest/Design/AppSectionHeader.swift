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

/// Non-blocking refresh feedback — shared by Portfolio and Research.
struct AppRefreshBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(AppColors.accent)
            Text(text)
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppColors.secondaryBackground.opacity(0.95))
        .overlay(alignment: .bottom) {
            Divider().overlay(AppColors.separator.opacity(0.5))
        }
    }
}
