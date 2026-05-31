import SwiftUI

struct FloatingAssistantButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BrandPrimary.onColor)
                .frame(width: 54, height: 54)
                .background(BrandPrimary.color)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(BrandPrimary.highlight.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open AI assistant")
    }
}

struct AssistantLauncherRow: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .frame(width: 32, height: 32)
                    .background(AppColors.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.bodySecondary.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.secondaryFill.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.panelBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
