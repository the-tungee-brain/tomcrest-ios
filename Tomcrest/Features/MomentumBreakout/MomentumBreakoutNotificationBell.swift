import SwiftUI

struct MomentumBreakoutNotificationBell: View {
    @Environment(AuthSession.self) private var auth
    var onOpenAlerts: (() -> Void)?

    @State private var viewModel: MomentumBreakoutNotificationsViewModel?
    @State private var showsSheet = false
    @State private var alertsEnabled = true
    @State private var notificationsEnabled = true

    var body: some View {
        Group {
            if auth.accessToken != nil,
               alertsEnabled,
               notificationsEnabled {
                Button {
                    showsSheet = true
                    Task { await viewModel?.load() }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryLabel)
                            .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        if let count = viewModel?.unreadCount, count > 0 {
                            Text(count > 9 ? "9+" : "\(count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppColors.background)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(AppColors.error)
                                .clipShape(Capsule())
                                .offset(x: 4, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
                .sheet(isPresented: $showsSheet) {
                    notificationSheet
                }
                .task {
                    if let token = auth.accessToken, !token.isEmpty {
                        if let status = try? await MomentumBreakoutAlertService.fetchFeatureStatus(
                            accessToken: token
                        ) {
                            alertsEnabled = status.flags.alertsEnabled
                            notificationsEnabled = status.flags.alertNotificationsEnabled
                        }
                    }
                    if viewModel == nil {
                        let model = MomentumBreakoutNotificationsViewModel(auth: auth)
                        viewModel = model
                        await model.load()
                    }
                }
            }
        }
    }

    private var accessibilityLabel: String {
        if let count = viewModel?.unreadCount, count > 0 {
            return "\(count) unread trade plan notifications"
        }
        return "Trade plan notifications"
    }

    private var notificationSheet: some View {
        NavigationStack {
            ScrollView {
                if let viewModel {
                    MomentumBreakoutNotificationList(viewModel: viewModel)
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.vertical, 16)
                }
            }
            .appCanvasScreen()
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { showsSheet = false }
                }
                if let onOpenAlerts {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("All alerts") {
                            showsSheet = false
                            onOpenAlerts()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
