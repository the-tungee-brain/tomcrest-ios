import SwiftUI

struct SettingsView: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel: SettingsViewModel?
    @State private var deleteExpanded = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    settingsContent(viewModel)
                } else {
                    ScrollView {
                        SettingsLoadingView()
                            .padding(.horizontal, Layout.horizontalPadding)
                            .padding(.top, 8)
                            .appNarrowContentWidth()
                    }
                }
            }
            .background(AppColors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if viewModel == nil {
                    let model = SettingsViewModel(auth: auth)
                    viewModel = model
                    await model.load()
                }
            }
        }
    }

    @ViewBuilder
    private func settingsContent(_ viewModel: SettingsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
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
                    StrategySettingsCard(viewModel: viewModel)
                }

                AppScreenSection(title: "Account & privacy") {
                    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                        if let email = viewModel.accountPlan?.email, !email.isEmpty {
                            AccountIdentityRow(email: email)
                        }

                        if let planError = viewModel.planError {
                            inlineError(planError)
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
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, 24)
            .appNarrowContentWidth()
        }
        .refreshable {
            await viewModel.load()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.isRefreshing {
                AppRefreshBanner(text: "Refreshing settings…")
            }
        }
    }

    private func inlineError(_ message: String) -> some View {
        AppInlineBanner(message: message, tone: .error)
    }
}

#Preview {
    AppPreview.environments {
        SettingsView()
            .environment(AuthSession())
            .environment(AccountContext())
    }
}
