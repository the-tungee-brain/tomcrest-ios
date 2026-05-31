import SwiftUI

struct SettingsLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            skeleton(height: 160)
            skeleton(height: 200)
            skeleton(height: 280)
        }
            .redacted(reason: .placeholder)
    }

    private func skeleton(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.secondaryBackground)
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
    }
}
