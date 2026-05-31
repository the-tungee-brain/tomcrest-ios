import SwiftUI

struct ChatQuickActionChips: View {
    let actions: [QuickActionDefinition]
    var disabled = false
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    AppChip(title: action.label) {
                        onSelect(action.id)
                    }
                    .disabled(disabled)
                    .opacity(disabled ? 0.5 : 1)
                }
            }
        }
    }
}
