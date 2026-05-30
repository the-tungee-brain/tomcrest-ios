import SwiftUI

struct SettingsView: View {
    @Environment(AuthSession.self) private var auth
    @State private var schwabConnected: Bool?
    @State private var isLoadingSchwab = false

    var body: some View {
        NavigationStack {
            List {
                Section("Brokerage") {
                    HStack {
                        Label("Schwab", systemImage: "link.circle.fill")
                        Spacer()
                        if isLoadingSchwab {
                            ProgressView()
                        } else if let schwabConnected {
                            Text(schwabConnected ? "Connected" : "Not connected")
                                .foregroundStyle(schwabConnected ? Theme.success : Theme.muted)
                        } else {
                            Text("Unknown")
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    Button("Refresh Schwab status") {
                        refreshSchwabStatus()
                    }

                    Button("Connect Schwab") {
                        connectSchwab()
                    }
                    .disabled(isLoadingSchwab)
                }

                Section("Account") {
                    Button("Sign out", role: .destructive) {
                        auth.signOut()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Support", value: AppConfig.supportEmail)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .task {
                refreshSchwabStatus()
            }
        }
    }

    private func refreshSchwabStatus() {
        isLoadingSchwab = true
        Task {
            schwabConnected = await auth.fetchSchwabStatus()
            isLoadingSchwab = false
        }
    }

    private func connectSchwab() {
        isLoadingSchwab = true
        Task {
            if let url = await auth.fetchSchwabConnectURL() {
                // Phase 2: open url in ASWebAuthenticationSession.
                auth.setError("Schwab OAuth UI coming in Phase 2. Auth URL ready: \(url.host ?? "schwab")")
            }
            isLoadingSchwab = false
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthSession())
}
