import SwiftUI

struct AccountSettingsScreen: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var deleteExpanded = false

    var body: some View {
        SettingsScreenShell(title: "Account") {
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

            AppScreenSection(title: "Danger zone") {
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
    }
}
