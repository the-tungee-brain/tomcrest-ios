import SwiftUI
import UIKit

/// Global UIKit chrome so the canvas background shows through navigation and scroll surfaces.
enum AppChrome {
    static func configure() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithTransparentBackground()
        navigation.backgroundColor = .clear
        navigation.shadowColor = .clear

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigation
        navigationBar.compactAppearance = navigation
        navigationBar.scrollEdgeAppearance = navigation
        navigationBar.isTranslucent = true

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
        UIScrollView.appearance().backgroundColor = .clear

        UIRefreshControl.appearance().tintColor = UIColor(red: 0.176, green: 0.831, blue: 0.749, alpha: 1)
    }

    static func clearTabBarController(_ tabBarController: UITabBarController) {
        tabBarController.view.backgroundColor = .clear
        tabBarController.view.isOpaque = false
        tabBarController.viewControllers?.forEach { controller in
            controller.view.backgroundColor = .clear
            controller.view.isOpaque = false
            clearHostingViews(in: controller.view)
        }
    }

    private static func clearHostingViews(in view: UIView) {
        let typeName = String(describing: type(of: view))
        if typeName.contains("Hosting") || view is UIScrollView {
            view.backgroundColor = .clear
            view.isOpaque = false
        }
        view.subviews.forEach { clearHostingViews(in: $0) }
    }
}

final class AppKeyboardDismissHandler: NSObject {
    static let shared = AppKeyboardDismissHandler()

    static func dismiss() {
        shared.dismissKeyboard()
    }

    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Navigation stack with canvas (iOS 17-safe; replaces iOS 18 containerBackground)

struct AppNavigationCanvasStack<Content: View>: View {
    @Environment(AppBrowserRouter.self) private var browser
    @ViewBuilder private var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            AppCanvasBackground()
                .ignoresSafeArea()

            NavigationStack {
                content()
                    .appInAppBrowser(browser)
                    .appKeyboardDoneToolbar()
            }
            .appClearUIKitBackground()
        }
    }
}

struct AppRoutedNavigationCanvasStack<Data, Content: View>: View where Data: Hashable {
    @Binding private var path: [Data]
    @Environment(AppBrowserRouter.self) private var browser
    @ViewBuilder private var content: () -> Content

    init(path: Binding<[Data]>, @ViewBuilder content: @escaping () -> Content) {
        _path = path
        self.content = content
    }

    var body: some View {
        ZStack {
            AppCanvasBackground()
                .ignoresSafeArea()

            NavigationStack(path: $path) {
                content()
                    .appInAppBrowser(browser)
                    .appKeyboardDoneToolbar()
            }
            .appClearUIKitBackground()
        }
    }
}

// MARK: - UIKit background clearer (TabView / NavigationStack host views)

private struct AppUIKitBackgroundClearer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        ClearerViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class ClearerViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let tabBarController {
            AppChrome.clearTabBarController(tabBarController)
        } else {
            clearTabBarControllerFromWindow()
        }
        clearNavigationBackgrounds(in: view)
    }

    private func clearTabBarControllerFromWindow() {
        guard let root = view.window?.rootViewController else { return }
        findTabBarController(in: root)
    }

    private func findTabBarController(in controller: UIViewController?) {
        guard let controller else { return }
        if let tabBarController = controller as? UITabBarController {
            AppChrome.clearTabBarController(tabBarController)
            return
        }
        controller.children.forEach { findTabBarController(in: $0) }
        findTabBarController(in: controller.presentedViewController)
    }

    private func clearNavigationBackgrounds(in view: UIView) {
        var current: UIView? = view
        while let node = current {
            let typeName = String(describing: type(of: node))
            if node is UIScrollView || typeName.contains("Hosting") || typeName.contains("Navigation") {
                node.backgroundColor = .clear
                node.isOpaque = false
            }
            current = node.superview
        }
    }
}

// MARK: - SwiftUI modifiers

extension View {
    /// Clears opaque UIKit layers SwiftUI inserts above parent backgrounds (TabView, etc.).
    func appClearUIKitBackground() -> some View {
        background(AppUIKitBackgroundClearer())
    }

    /// Transparent navigation chrome so the canvas shows behind titles.
    func appNavigationCanvas() -> some View {
        toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
    }

    /// Scroll + navigation chrome for screen shells (`AppScrollScreen`, etc.).
    func appCanvasScreen() -> some View {
        scrollContentBackground(.hidden)
            .appNavigationCanvas()
    }

    /// Canvas behind pushed navigation destinations (symbol research, portfolio symbol drill-in).
    func appPushedScreenCanvas() -> some View {
        modifier(AppPushedScreenCanvasModifier())
    }
}

private struct AppPushedScreenCanvasModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppCanvasBackground()
                .ignoresSafeArea()
            content
        }
        .appClearUIKitBackground()
    }
}
