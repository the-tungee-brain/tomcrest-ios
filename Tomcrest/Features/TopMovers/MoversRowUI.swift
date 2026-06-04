import SwiftUI

enum MoversRowMetrics {
    static let expandedSpacing: CGFloat = 14
    static let expandedHorizontalPadding: CGFloat = 16
    static let expandedBottomPadding: CGFloat = 16
}

struct MoversExpandedDivider: View {
    var body: some View {
        Divider().overlay(Token.gridLine)
    }
}

struct MoversSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Token.textSecondary)
            .tracking(0.6)
    }
}

struct MoversCalloutBlock<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Token.surfaceFillSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MoversBulletListSection: View {
    let title: String
    let lines: [String]
    var style: Style = .checkmark

    enum Style {
        case checkmark
        case warning
        case bullet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MoversSectionTitle(title: title)
            if lines.isEmpty {
                Text("—")
                    .font(.footnote)
                    .foregroundStyle(Token.textSecondary)
            } else {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        leadingMark
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(Token.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var leadingMark: some View {
        switch style {
        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(AppColors.success)
        case .warning:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(AppColors.warning)
        case .bullet:
            Text("•")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Token.textTertiary)
        }
    }
}

struct SetupStageBadge: View {
    let stage: SetupStageId
    let label: String

    var body: some View {
        Text(shortLabel)
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(foreground.opacity(0.14))
            .clipShape(Capsule())
            .accessibilityLabel("Setup stage \(label)")
    }

    private var shortLabel: String {
        switch stage {
        case .breakoutWatch: "Watch"
        case .tightening: "Tight"
        case .baseBuilding: "Base"
        case .breakoutTriggered: "Triggered"
        case .extended: "Extended"
        }
    }

    private var foreground: Color {
        switch stage {
        case .breakoutWatch, .tightening: Token.primary
        case .baseBuilding: AppColors.success
        case .breakoutTriggered: AppColors.warning
        case .extended: Token.textSecondary
        }
    }
}

enum EmergingLeadersFormatting {
    static func rankLabel(_ rank: Int) -> String {
        "#\(rank)"
    }

    static func setupScoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 65 { return AppColors.warning }
        if score < 50 { return AppColors.error }
        return Token.textPrimary
    }
}
