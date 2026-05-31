import SwiftUI

/// Standard root scroll layout — canvas shows through, consistent padding and width.
struct AppScrollScreen<Content: View>: View {
    var spacing: CGFloat = Layout.sectionSpacing
    var maxWidth: CGFloat = Layout.contentMaxWidth
    var topPadding: CGFloat = 0
    var refresh: (() async -> Void)?
    private let content: () -> Content

    init(
        spacing: CGFloat = Layout.sectionSpacing,
        maxWidth: CGFloat = Layout.contentMaxWidth,
        topPadding: CGFloat = 0,
        refresh: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.maxWidth = maxWidth
        self.topPadding = topPadding
        self.refresh = refresh
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .appScreenContent(maxWidth: maxWidth, topPadding: topPadding)
        }
        .appCanvasScreen()
        .modifier(RefreshableModifier(refresh: refresh))
    }
}

/// Narrow settings-style scroll shell.
struct AppNarrowScrollScreen<Content: View>: View {
    var refresh: (() async -> Void)?
    private let content: () -> Content

    init(
        refresh: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.refresh = refresh
        self.content = content
    }

    var body: some View {
        AppScrollScreen(maxWidth: Layout.narrowContentMaxWidth, refresh: refresh, content: content)
    }
}

private struct RefreshableModifier: ViewModifier {
    let refresh: (() async -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let refresh {
            content.refreshable { await refresh() }
        } else {
            content
        }
    }
}

extension View {
    /// Horizontal padding + max content width used inside scroll stacks.
    func appScreenContent(
        maxWidth: CGFloat = Layout.contentMaxWidth,
        topPadding: CGFloat = 0
    ) -> some View {
        padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, 24)
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    }

    /// Large-title root navigation chrome — portfolio, research hub, settings.
    func appRootNavigation(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .appNavigationCanvas()
    }

    /// Detail navigation — symbol research, pushed settings rows.
    func appDetailNavigation() -> some View {
        navigationBarTitleDisplayMode(.inline)
            .appNavigationCanvas()
    }
}
