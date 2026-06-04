import SwiftUI

struct MomentumBreakoutNotificationList: View {
    @Bindable var viewModel: MomentumBreakoutNotificationsViewModel
    var showsDisclaimer = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsDisclaimer {
                Text("Educational trade plan notifications only. Not investment advice. No orders are placed.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            if let error = viewModel.errorMessage, viewModel.notifications.isEmpty {
                AppInlineBanner(message: error, tone: .error)
            }

            if viewModel.isLoading, viewModel.notifications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if viewModel.notifications.isEmpty, viewModel.errorMessage == nil {
                Text("No notifications yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                AppGroupedList {
                    ForEach(Array(viewModel.notifications.enumerated()), id: \.element.id) { index, row in
                        MomentumBreakoutNotificationRow(
                            notification: row,
                            onMarkRead: {
                                Task { await viewModel.markRead(notificationId: row.notificationId) }
                            }
                        )
                        if index < viewModel.notifications.count - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct MomentumBreakoutNotificationRow: View {
    let notification: MomentumBreakoutNotificationDto
    let onMarkRead: () -> Void

    var body: some View {
        Button(action: onMarkRead) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    severityChip
                    Spacer()
                    Text(notification.createdAt.prefix(10))
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
                Text(notification.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                    .multilineTextAlignment(.leading)
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                if !notification.read {
                    Text("Tap to mark read")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(notification.read ? Color.clear : AppColors.accentMuted.opacity(0.2))
        }
        .buttonStyle(.plain)
    }

    private var severityChip: some View {
        let severity = notification.notificationSeverity
        let colors: (Color, Color)
        switch severity {
        case .critical:
            colors = (AppColors.error.opacity(0.15), AppColors.error)
        case .warning:
            colors = (Color.orange.opacity(0.15), Color.orange)
        case .watch:
            colors = (Color.orange.opacity(0.1), Color.orange)
        default:
            colors = (AppColors.insetSurface, AppColors.secondaryLabel)
        }
        return Text(notification.eventType)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(colors.1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(colors.0)
            .clipShape(Capsule())
    }
}
