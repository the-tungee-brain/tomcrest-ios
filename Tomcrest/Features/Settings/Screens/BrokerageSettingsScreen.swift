import SwiftUI

struct BrokerageSettingsScreen: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        SettingsScreenShell(title: "Brokerage") {
            SchwabConnectionCard(
                connected: viewModel.schwabConnected,
                isLoading: viewModel.isLoadingSchwab,
                onConnect: { Task { await viewModel.connectSchwab() } },
                onDisconnect: { Task { await viewModel.disconnectSchwab() } }
            )

            Text("Tomcrest uses read-only Schwab access to show your holdings and power portfolio insights. Trades are never placed from the app.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(3)
                .padding(.horizontal, 4)
        }
    }
}
