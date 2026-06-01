import SwiftUI

struct BrandTaglineRotator: View {
    let phrases: [String]
    let theme: BrandTheme
    var interval: TimeInterval = 2

    @State private var index = 0

    var body: some View {
        Text(phrases[index])
            .font(AppTypography.bodySecondary)
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: 280)
            .id(index)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(BrandMotion.taglineFade, value: index)
            .task {
                guard phrases.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(interval))
                    withAnimation(BrandMotion.taglineFade) {
                        index = (index + 1) % phrases.count
                    }
                }
            }
    }
}
