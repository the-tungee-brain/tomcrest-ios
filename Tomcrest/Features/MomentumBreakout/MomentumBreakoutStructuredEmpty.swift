import SwiftUI

struct MomentumBreakoutStructuredEmpty: View {
    let title: String
    let happened: String
    let doing: String
    let expectNext: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.label)
            emptyBlock(label: "What happened", body: happened)
            emptyBlock(label: "What we're doing", body: doing)
            emptyBlock(label: "What to expect next", body: expectNext)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }

    private func emptyBlock(label: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.label)
            Text(body)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
