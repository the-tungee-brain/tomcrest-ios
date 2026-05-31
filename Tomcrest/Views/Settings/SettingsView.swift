import SwiftUI

struct SettingsView: View {
    @Environment(AuthSession.self) private var auth
    @Binding var settingsFocus: SettingsFocus?
    @State private var viewModel: SettingsViewModel?
    @State private var deleteExpanded = false
    @State private var strategyExpanded = false

    init(settingsFocus: Binding<SettingsFocus?> = .constant(nil)) {
        _settingsFocus = settingsFocus
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    settingsContent(viewModel)
                } else {
                    AppNarrowScrollScreen {
                        SettingsLoadingView()
                            .padding(.top, 8)
                    }
                }
            }
            .appRootNavigation("Settings")
            .task {
                if viewModel == nil {
                    let model = SettingsViewModel(auth: auth)
                    viewModel = model
                    await model.load()
                }
            }
            .onChange(of: settingsFocus) { _, focus in
                guard focus == .strategy else { return }
                strategyExpanded = true
                settingsFocus = nil
            }
        }
    }

    @ViewBuilder
    private func settingsContent(_ viewModel: SettingsViewModel) -> some View {
        AppNarrowScrollScreen(refresh: { await viewModel.load() }) {
            if let bannerMessage = viewModel.bannerMessage {
                AppInlineBanner(
                    message: bannerMessage,
                    tone: viewModel.bannerIsSuccess ? .success : .error
                )
            }

            AppScreenSection(title: "Brokerage") {
                SchwabConnectionCard(
                    connected: viewModel.schwabConnected,
                    isLoading: viewModel.isLoadingSchwab,
                    onConnect: { Task { await viewModel.connectSchwab() } },
                    onDisconnect: { Task { await viewModel.disconnectSchwab() } }
                )
            }

            AppScreenSection(title: "Investment strategy") {
                StrategySettingsCard(viewModel: viewModel, strategyExpanded: $strategyExpanded)
            }

            AppScreenSection(title: "Account & privacy") {
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    if let email = viewModel.accountPlan?.email, !email.isEmpty {
                        AccountIdentityRow(email: email)
                    }

                    if let planError = viewModel.planError {
                        AppInlineBanner(message: planError, tone: .error)
                    }

                    AccountPlanCardView(
                        plan: viewModel.accountPlan,
                        isLoading: viewModel.isLoadingPlan
                    )

                    AccountSessionPanel(onSignOut: { viewModel.signOut() })

                    AppDisclosureSection(title: "Delete account", isExpanded: $deleteExpanded) {
                        DeleteAccountCard(
                            confirmDelete: viewModel.confirmDelete,
                            isDeleting: viewModel.isDeletingAccount,
                            error: viewModel.deleteError,
                            onBeginDelete: viewModel.beginDeleteAccount,
                            onConfirmDelete: { Task { await viewModel.deleteAccount() } },
                            onCancelDelete: viewModel.cancelDeleteAccount
                        )
                    }
                }
            }

            AppScreenSection(title: "About") {
                SettingsAboutCard()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.isRefreshing {
                AppRefreshBanner(text: "Refreshing settings…")
            }
        }
    }
}

#Preview {
    AppPreview.environments {
        SettingsView()
            .environment(AuthSession())
            .environment(AccountContext())
    }
}
