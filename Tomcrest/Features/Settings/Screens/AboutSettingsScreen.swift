import SwiftUI

struct AboutSettingsScreen: View {
    var body: some View {
        SettingsScreenShell(title: "About") {
            SettingsGroup {
                HStack {
                    Text("Version")
                        .foregroundStyle(AppColors.label)
                    Spacer()
                    Text("0.1.0")
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                SettingsGroupDivider()

                HStack {
                    Text("Support")
                        .foregroundStyle(AppColors.label)
                    Spacer()
                    Link(AppConfig.supportEmail, destination: supportURL)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.accentHighlight)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Text("Tomcrest helps you understand your portfolio, research symbols, and follow a strategy playbook — without placing trades.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(3)
                .padding(.horizontal, 4)
        }
    }

    private var supportURL: URL {
        URL(string: "mailto:\(AppConfig.supportEmail)")!
    }
}
