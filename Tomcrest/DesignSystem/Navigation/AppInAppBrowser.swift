import SwiftUI
import WebKit

struct IdentifiableURL: Identifiable, Hashable {
    let url: URL

    var id: String { url.absoluteString }
}

@MainActor
@Observable
final class AppBrowserRouter {
    var presentedURL: IdentifiableURL?

    func open(_ url: URL) {
        AppExternalURLPolicy.open(url) { presented in
            presentedURL = IdentifiableURL(url: presented)
        }
    }

    func dismiss() {
        presentedURL = nil
    }
}

enum AppExternalURLPolicy {
    static func shouldOpenInApp(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    static func open(_ url: URL, inApp: (URL) -> Void) {
        if shouldOpenInApp(url) {
            inApp(url)
        } else {
            UIApplication.shared.open(url)
        }
    }
}

struct OpenExternalURLAction {
    private let handler: (URL) -> Void

    init(_ handler: @escaping (URL) -> Void) {
        self.handler = handler
    }

    func callAsFunction(_ url: URL) {
        handler(url)
    }
}

private struct OpenExternalURLKey: EnvironmentKey {
    static let defaultValue = OpenExternalURLAction { url in
        AppExternalURLPolicy.open(url, inApp: { UIApplication.shared.open($0) })
    }
}

extension EnvironmentValues {
    var openExternalURL: OpenExternalURLAction {
        get { self[OpenExternalURLKey.self] }
        set { self[OpenExternalURLKey.self] = newValue }
    }
}

/// Opens http(s) links in the in-app browser; mailto/tel still use the system handler.
struct AppExternalLink<Label: View>: View {
    let url: URL
    @ViewBuilder var label: () -> Label

    @Environment(AppBrowserRouter.self) private var browser

    var body: some View {
        Button {
            browser.open(url)
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }
}

/// App-wide link routing — apply once at the root (TomcrestApp / AppShell).
struct AppBrowserHostModifier: ViewModifier {
    @Bindable var browser: AppBrowserRouter

    func body(content: Content) -> some View {
        content
            .environment(\.openExternalURL, OpenExternalURLAction { url in
                browser.open(url)
            })
            .environment(\.openURL, OpenURLAction { url in
                if AppExternalURLPolicy.shouldOpenInApp(url) {
                    browser.open(url)
                    return .handled
                }
                return .systemAction
            })
            .appInAppBrowserSheet(browser)
    }
}

extension View {
    func appBrowserHost(_ browser: AppBrowserRouter) -> some View {
        modifier(AppBrowserHostModifier(browser: browser))
    }
}

struct AppInAppBrowserHostModifier: ViewModifier {
    @Bindable var browser: AppBrowserRouter

    func body(content: Content) -> some View {
        content
            .environment(\.openExternalURL, OpenExternalURLAction { url in
                browser.open(url)
            })
            .environment(\.openURL, OpenURLAction { url in
                if AppExternalURLPolicy.shouldOpenInApp(url) {
                    browser.open(url)
                    return .handled
                }
                return .systemAction
            })
    }
}

extension View {
    func appInAppBrowser(_ browser: AppBrowserRouter) -> some View {
        modifier(AppInAppBrowserHostModifier(browser: browser))
    }

    func appInAppBrowserSheet(_ browser: AppBrowserRouter) -> some View {
        modifier(AppInAppBrowserSheetModifier(browser: browser))
    }
}

private struct AppInAppBrowserSheetModifier: ViewModifier {
    @Bindable var browser: AppBrowserRouter

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $browser.presentedURL) { item in
                NavigationStack {
                    InAppBrowserScreen(url: item.url)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") {
                                    browser.dismiss()
                                }
                            }
                        }
                }
            }
    }
}

struct InAppBrowserScreen: View {
    let url: URL

    @State private var isLoading = true
    @State private var canGoBack = false
    @State private var pageTitle: String?

    var body: some View {
        AppWebView(
            url: url,
            isLoading: $isLoading,
            canGoBack: $canGoBack,
            pageTitle: $pageTitle
        )
        .overlay(alignment: .top) {
            if isLoading {
                ProgressView()
                    .tint(AppColors.accent)
                    .padding(.top, 8)
            }
        }
        .navigationTitle(pageTitle ?? displayHost)
        .navigationBarTitleDisplayMode(.inline)
        .appPushedScreenCanvas()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canGoBack {
                    Button {
                        NotificationCenter.default.post(name: .appWebViewGoBack, object: nil)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Back")
                }

                Menu {
                    Button("Open in Safari") {
                        UIApplication.shared.open(url)
                    }
                    Button("Copy link") {
                        UIPasteboard.general.url = url
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Browser actions")
            }
        }
    }

    private var displayHost: String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? "Web"
    }
}

extension Notification.Name {
    fileprivate static let appWebViewGoBack = Notification.Name("appWebViewGoBack")
}

private struct AppWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var pageTitle: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, canGoBack: $canGoBack, pageTitle: $pageTitle)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        context.coordinator.webView = webView
        context.coordinator.observeBackNotification()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObservingBackNotification()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var canGoBack: Bool
        @Binding var pageTitle: String?
        weak var webView: WKWebView?
        private var backObserver: NSObjectProtocol?

        init(isLoading: Binding<Bool>, canGoBack: Binding<Bool>, pageTitle: Binding<String?>) {
            _isLoading = isLoading
            _canGoBack = canGoBack
            _pageTitle = pageTitle
        }

        func observeBackNotification() {
            backObserver = NotificationCenter.default.addObserver(
                forName: .appWebViewGoBack,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.webView?.goBack()
            }
        }

        func stopObservingBackNotification() {
            if let backObserver {
                NotificationCenter.default.removeObserver(backObserver)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            canGoBack = webView.canGoBack
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            canGoBack = webView.canGoBack
            pageTitle = webView.title
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            canGoBack = webView.canGoBack
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            canGoBack = webView.canGoBack
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
