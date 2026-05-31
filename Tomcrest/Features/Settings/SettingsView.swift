import SwiftUI

struct SettingsView: View {
    @Environment(AuthSession.self) private var auth
    @Binding var settingsFocus: SettingsFocus?
    @State private var viewModel: SettingsViewModel?
    @State private var path: [SettingsDestination] = []

    init(settingsFocus: Binding<SettingsFocus?> = .constant(nil)) {
        _settingsFocus = settingsFocus
    }

    var body: some View {
        AppRoutedNavigationCanvasStack(path: $path) {
            Group {
                if let viewModel {
                    settingsHub(viewModel)
                } else {
                    AppNarrowScrollScreen {
                        SettingsLoadingView()
                            .padding(.top, 8)
                    }
                }
            }
            .appRootNavigation("Settings")
            .navigationDestination(for: SettingsDestination.self) { destination in
                if let viewModel {
                    settingsDestination(destination, viewModel: viewModel)
                }
            }
            .task {
                if viewModel == nil {
                    let model = SettingsViewModel(auth: auth)
                    viewModel = model
                    await model.load()
                }
            }
            .onChange(of: settingsFocus) { _, focus in
                guard focus == .strategy else { return }
                path = [.strategy]
                settingsFocus = nil
            }
        }
    }

    @ViewBuilder
    private func settingsHub(_ viewModel: SettingsViewModel) -> some View {
        AppNarrowScrollScreen(refresh: { await viewModel.load() }) {
            SettingsProfileHeader(
                email: viewModel.accountPlan?.email,
                planLabel: viewModel.accountPlan?.isPaid == true ? "Pro" : "Free",
                isPaid: viewModel.accountPlan?.isPaid == true
            )

            if let bannerMessage = viewModel.bannerMessage {
                AppInlineBanner(
                    message: bannerMessage,
                    tone: viewModel.bannerIsSuccess ? .success : .error
                )
            }

            SettingsGroup {
                navigationRow(
                    destination: .brokerage,
                    icon: "building.columns.fill",
                    iconTint: AppColors.accentHighlight,
                    title: "Brokerage",
                    subtitle: "Schwab connection",
                    value: schwabStatusLabel(viewModel)
                )
                SettingsGroupDivider()
                navigationRow(
                    destination: .strategy,
                    icon: "sparkles",
                    iconTint: Color(hex: 0xa78bfa),
                    title: "Strategy",
                    subtitle: "Playbook & preferences",
                    value: viewModel.selectedStrategyTitle ?? "Choose"
                )
            }

            SettingsGroup(footer: "Account details, plan features, and data deletion.") {
                navigationRow(
                    destination: .account,
                    icon: "person.crop.circle.fill",
                    iconTint: AppColors.accent,
                    title: "Account & plan",
                    subtitle: nil,
                    value: viewModel.accountPlan?.isPaid == true ? "Pro" : "Free"
                )
                SettingsGroupDivider()
                navigationRow(
                    destination: .legal,
                    icon: "doc.text.fill",
                    iconTint: AppColors.secondaryLabel,
                    title: "Legal",
                    subtitle: nil,
                    value: nil
                )
                SettingsGroupDivider()
                navigationRow(
                    destination: .about,
                    icon: "info.circle.fill",
                    iconTint: AppColors.secondaryLabel,
                    title: "About",
                    subtitle: nil,
                    value: nil
                )
            }

            Button("Log out", role: .destructive) {
                viewModel.signOut()
            }
            .buttonStyle(AppSecondaryButtonStyle(destructive: true))
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.isRefreshing {
                AppRefreshBanner(text: "Refreshing…")
            }
        }
    }

    @ViewBuilder
    private func navigationRow(
        destination: SettingsDestination,
        icon: String,
        iconTint: Color,
        title: String,
        subtitle: String?,
        value: String?
    ) -> some View {
        NavigationLink(value: destination) {
            SettingsNavigationRow(
                icon: icon,
                iconTint: iconTint,
                title: title,
                subtitle: subtitle,
                value: value
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func settingsDestination(
        _ destination: SettingsDestination,
        viewModel: SettingsViewModel
    ) -> some View {
        switch destination {
        case .brokerage:
            BrokerageSettingsScreen(viewModel: viewModel)
        case .strategy:
            StrategySettingsScreen(viewModel: viewModel)
        case .account:
            AccountSettingsScreen(viewModel: viewModel)
        case .legal:
            LegalSettingsScreen()
        case .about:
            AboutSettingsScreen()
        }
    }

    private func schwabStatusLabel(_ viewModel: SettingsViewModel) -> String {
        if viewModel.isLoadingSchwab, viewModel.schwabConnected == nil {
            return "…"
        }
        if viewModel.schwabConnected == true { return "Connected" }
        if viewModel.schwabConnected == false { return "Off" }
        return "—"
    }
}

#Preview {
    AppPreview.environments {
        SettingsView()
            .environment(AuthSession())
            .environment(AccountContext())
    }
}
