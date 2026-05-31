import SwiftUI
import UIKit

/// Standard root scroll layout — canvas shows through, consistent padding and width.
struct AppScrollScreen<Content: View>: View {
    var spacing: CGFloat = Layout.sectionSpacing
    var maxWidth: CGFloat = Layout.contentMaxWidth
    var topPadding: CGFloat = 0
    var refresh: (() async -> Void)?
    private let content: () -> Content

    @State private var viewportWidth: CGFloat = 0

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
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .appScreenContent(maxWidth: maxWidth, topPadding: topPadding)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .frame(width: viewportWidth > 0 ? viewportWidth : nil, alignment: .leading)
            .background(AppOuterScrollBehavior())
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ScrollViewportWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(ScrollViewportWidthKey.self) { viewportWidth = $0 }
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

/// Horizontal scroll row constrained to the parent's width — safe inside vertical `ScrollView`s.
struct AppHorizontalScrollRow<Content: View>: View {
    var showsIndicators = false
    @ViewBuilder var content: () -> Content

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            content()
        }
        .frame(width: availableWidth > 0 ? availableWidth : nil, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.width, initial: true) { _, width in
                        availableWidth = width
                    }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
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

private struct ScrollViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Disables horizontal rubber-banding on the hosting vertical scroll view only.
private struct AppOuterScrollBehavior: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var ancestor = uiView.superview
            while let current = ancestor {
                if let scrollView = current as? UIScrollView {
                    scrollView.alwaysBounceHorizontal = false
                    scrollView.showsHorizontalScrollIndicator = false
                    return
                }
                ancestor = current.superview
            }
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
