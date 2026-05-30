import SwiftUI

struct ResearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.muted)
                    TextField("Search symbols", text: $query)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundStyle(Theme.foreground)
                }
                .padding(14)
                .background(Theme.panelBackgroundSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.border.opacity(0.6), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Phase 5")
                        .font(.headline)
                        .foregroundStyle(Theme.foreground)
                    Text("Symbol search hits `/symbols/search`. Overview uses `/research/overview-bundle`.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appPanel(subtle: true)

                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("Research")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ResearchView()
}
