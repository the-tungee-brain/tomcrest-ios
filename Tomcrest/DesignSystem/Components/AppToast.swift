import SwiftUI

private struct AppToastPresenterKey: EnvironmentKey {
    static let defaultValue: AppToastPresenter? = nil
}

extension EnvironmentValues {
    var appToastPresenter: AppToastPresenter? {
        get { self[AppToastPresenterKey.self] }
        set { self[AppToastPresenterKey.self] = newValue }
    }
}

extension View {
    func appToastPresenter(_ presenter: AppToastPresenter) -> some View {
        environment(\.appToastPresenter, presenter)
            .environment(presenter)
    }
}

@MainActor
@Observable
final class AppToastPresenter {
    private(set) var message: String?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, duration: TimeInterval = 2.4) {
        dismissTask?.cancel()
        self.message = message
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            if self.message == message {
                self.message = nil
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        message = nil
    }
}

private struct AppToastOverlay: View {
    @Environment(AppToastPresenter.self) private var toasts

    var body: some View {
        VStack {
            if let message = toasts.message {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.secondaryBackground.opacity(0.96))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppColors.panelBorder, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: toasts.message)
        .allowsHitTesting(false)
    }
}

extension View {
    func appToastHost(_ toasts: AppToastPresenter) -> some View {
        overlay(alignment: .top) {
            AppToastOverlay()
                .environment(toasts)
        }
    }
}
