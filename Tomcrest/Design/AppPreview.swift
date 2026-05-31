import SwiftUI

#if DEBUG
/// Preview both appearances — semantic colors adapt when scheme changes.
enum AppPreview {
    static func environments<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Group {
            content()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")

            content()
                .preferredColorScheme(.light)
                .previewDisplayName("Light")
        }
    }
}
#endif
