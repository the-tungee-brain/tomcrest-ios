import SwiftUI

struct LegalSettingsScreen: View {
    var body: some View {
        SettingsScreenShell(title: "Legal") {
            SettingsGroup {
                SettingsLinkRow(title: "Security overview", url: AppConfig.securityURL)
                SettingsGroupDivider()
                SettingsLinkRow(title: "Privacy Policy", url: AppConfig.privacyURL)
                SettingsGroupDivider()
                SettingsLinkRow(title: "Terms of Service", url: AppConfig.termsURL)
            }

            Text("These pages open in your browser. They describe how Tomcrest handles your data and keeps your account secure.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(3)
                .padding(.horizontal, 4)
        }
    }
}
