import SwiftUI

// MARK: - Hub profile

struct SettingsProfileHeader: View {
    let email: String?
    let planLabel: String
    let isPaid: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.accentMuted)
                    .frame(width: 56, height: 56)
                Image(systemName: "person.fill")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(AppColors.accentHighlight)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayEmail)
                    .font(.headline)
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)

                Text(planSubtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)

                Text(planLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isPaid ? AppColors.accentHighlight : AppColors.secondaryLabel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isPaid ? AppColors.accentMuted : AppColors.secondaryFill)
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var displayEmail: String {
        if let email, !email.isEmpty { return email }
        return "Your account"
    }

    private var planSubtitle: String {
        isPaid ? "Pro access" : "Free plan"
    }
}

// MARK: - Grouped list (Settings.app style)

struct SettingsGroup<Content: View>: View {
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                content()
            }
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.panelBorder, lineWidth: 1)
            }

            if let footer {
                Text(footer)
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    var iconTint: Color = AppColors.accentHighlight
    let title: String
    var subtitle: String?
    var value: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 30, height: 30)
                .background(iconTint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppColors.label)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Layout.minTouchTarget)
        .contentShape(Rectangle())
    }
}

struct SettingsGroupDivider: View {
    var body: some View {
        Divider()
            .overlay(AppColors.separator)
            .padding(.leading, 58)
    }
}

struct SettingsLinkRow: View {
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppColors.label)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: Layout.minTouchTarget)
            .contentShape(Rectangle())
        }
    }
}

struct SettingsScreenShell<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        AppNarrowScrollScreen {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                content()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
