import SwiftUI

struct ContactSettingsScreen: View {
    @Environment(AppBrowserRouter.self) private var browser

    var body: some View {
        SettingsScreenShell(title: "Contact") {
            Text("Questions about Tomcrest, access, or your account? Reach out and we'll get back to you.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(3)
                .padding(.horizontal, 4)

            SettingsGroup {
                Button {
                    browser.open(AppConfig.supportEmailURL)
                } label: {
                    SettingsNavigationRow(
                        icon: "envelope.fill",
                        iconTint: AppColors.accentHighlight,
                        title: "Email support",
                        subtitle: AppConfig.supportEmail,
                        value: nil
                    )
                }
                .buttonStyle(.plain)

                SettingsGroupDivider()

                Button {
                    browser.open(URL(string: "https://tomcrest.com/contact")!)
                } label: {
                    SettingsNavigationRow(
                        icon: "globe",
                        iconTint: AppColors.secondaryLabel,
                        title: "Contact form",
                        subtitle: "tomcrest.com/contact",
                        value: nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
