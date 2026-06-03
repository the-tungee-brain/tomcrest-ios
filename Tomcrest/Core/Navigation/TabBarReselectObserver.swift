import SwiftUI
import UIKit

/// Detects re-taps on the current tab bar item (pop-to-root).
struct TabBarReselectObserver: UIViewControllerRepresentable {
    let coordinator: TabBarReselectCoordinator
    let tabs: [AppTab]
    let selectedTab: AppTab
    var reinstallToken: Int = 0

    func makeCoordinator() -> Installer {
        Installer(coordinator: coordinator, tabs: tabs, selectedTab: selectedTab)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = PassthroughViewController()
        controller.onLayout = { [weak installer = context.coordinator] in
            installer?.installFromWindow()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        _ = reinstallToken
        context.coordinator.selectedTab = selectedTab
        context.coordinator.installFromWindow()
        context.coordinator.installFromHierarchy(startingAt: uiViewController)
    }

    private final class PassthroughViewController: UIViewController {
        var onLayout: (() -> Void)?

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            onLayout?()
        }
    }

    final class Installer: NSObject {
        let coordinator: TabBarReselectCoordinator
        let tabs: [AppTab]
        var selectedTab: AppTab
        private weak var tabBar: UITabBar?

        init(coordinator: TabBarReselectCoordinator, tabs: [AppTab], selectedTab: AppTab) {
            self.coordinator = coordinator
            self.tabs = tabs
            self.selectedTab = selectedTab
        }

        func installFromWindow() {
            guard let root = Self.keyWindowRootViewController(),
                  let tabBarController = Self.findTabBarController(in: root) else {
                return
            }
            wireTabBar(tabBarController.tabBar)
        }

        func installFromHierarchy(startingAt viewController: UIViewController) {
            if let tabBarController = viewController.tabBarController {
                wireTabBar(tabBarController.tabBar)
            }
        }

        private func wireTabBar(_ tabBar: UITabBar) {
            self.tabBar = tabBar
            let controls = tabBar.subviews
                .filter { $0 is UIControl }
                .sorted { $0.frame.minX < $1.frame.minX }
            guard controls.count == tabs.count else { return }

            for (index, control) in controls.enumerated() {
                guard let control = control as? UIControl else { continue }
                control.removeTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
                control.tag = index
                control.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
            }
        }

        @objc private func tabButtonTapped(_ sender: UIControl) {
            guard tabs.indices.contains(sender.tag) else { return }
            let tab = tabs[sender.tag]
            guard tab == selectedTab else { return }
            Task { @MainActor in
                coordinator.noteReselect(tab)
            }
        }

        private static func keyWindowRootViewController() -> UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
        }

        private static func findTabBarController(in controller: UIViewController?) -> UITabBarController? {
            guard let controller else { return nil }
            if let tabBarController = controller as? UITabBarController {
                return tabBarController
            }
            for child in controller.children {
                if let found = findTabBarController(in: child) { return found }
            }
            return findTabBarController(in: controller.presentedViewController)
        }
    }
}
