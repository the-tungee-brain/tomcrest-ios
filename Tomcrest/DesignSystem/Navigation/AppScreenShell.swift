import SwiftUI

/// Standard root scroll layout
struct AppScrollScreen<Content: View>: View {
    var spacing: CGFloat = Layout.sectionSpacing
    var maxWidth: CGFloat = Layout.contentMaxWidth
    var topPadding: CGFloat = 0
    var refresh: (() async -> Void)?
    var scrollToToken: Binding<Int>?
    var scrollAnchor: String = AppScrollAnchor.chat
    private let content: () -> Content

    init(
        spacing: CGFloat = Layout.sectionSpacing,
        maxWidth: CGFloat = Layout.contentMaxWidth,
        topPadding: CGFloat = 0,
        refresh: (() async -> Void)? = nil,
        scrollToToken: Binding<Int>? = nil,
        scrollAnchor: String = AppScrollAnchor.chat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.maxWidth = maxWidth
        self.topPadding = topPadding
        self.refresh = refresh
        self.scrollToToken = scrollToToken
        self.scrollAnchor = scrollAnchor
        self.content = content
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: spacing) {
                    content()
                }
                .appScreenContent(maxWidth: maxWidth, topPadding: topPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollToToken?.wrappedValue ?? 0) { _, token in
                guard token > 0 else { return }
                scrollToChat(using: proxy)
            }
        }
        .appCanvasScreen()
        .modifier(RefreshableModifier(refresh: refresh))
    }

    private func scrollToChat(using proxy: ScrollViewProxy) {
        // Brief delay so tab switches and chat expand layout finish before scrolling.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(scrollAnchor, anchor: UnitPoint(x: 0.5, y: 0.12))
            }
        }
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

/// Horizontal scroll row constrained to the parent's width — safe inside vertical `ScrollView`s.
struct AppHorizontalScrollRow<Content: View>: View {
    var showsIndicators = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

/// Wrapping chip layout — avoids nested horizontal scroll inside vertical screens.
struct AppWrappingChipGrid<Item: Hashable, Chip: View>: View {
    let items: [Item]
    var minimumChipWidth: CGFloat = 132
    var spacing: CGFloat = 8
    @ViewBuilder var chip: (Item) -> Chip

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimumChipWidth), spacing: spacing)],
            alignment: .leading,
            spacing: spacing
        ) {
            ForEach(items, id: \.self) { item in
                chip(item)
            }
        }
    }
}

extension View {
    /// Anchor for scroll-to-chat — pair with `AppScrollScreen(scrollToToken:)`.
    func appChatScrollAnchor() -> some View {
        id(AppScrollAnchor.chat)
    }

    /// Horizontal padding + max content width used inside scroll stacks.
    func appScreenContent(
        maxWidth: CGFloat = Layout.contentMaxWidth,
        topPadding: CGFloat = 0
    ) -> some View {
        padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, 24)
            .frame(maxWidth: maxWidth, alignment: .leading)
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
