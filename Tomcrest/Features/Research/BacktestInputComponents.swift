import SwiftUI

enum BacktestInputComponents {
    static func parseDecimal(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
        return Double(normalized)
    }

    static func formatDecimal(_ value: Double, fractionDigits: Int = 2) -> String {
        guard value > 0 else { return "" }
        if fractionDigits == 0 {
            return String(format: "%.0f", value)
        }
        var formatted = String(format: "%.\(fractionDigits)f", value)
        while formatted.contains("."), formatted.last == "0" || formatted.last == "." {
            formatted.removeLast()
        }
        return formatted
    }
}

struct BacktestControlsShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }
}

struct BacktestSectionLabel: View {
    let title: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(2)
            }
        }
    }
}

struct BacktestDecimalField: View {
    let label: String
    let placeholder: String
    var prefix: String?
    var suffix: String?
    @Binding var value: Double
    var allowsEmpty = false
    var fractionDigits = 2

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.secondaryLabel)

            HStack(spacing: 6) {
                if let prefix {
                    Text(prefix)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                }

                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(AppColors.label)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { commit() }

                if let suffix {
                    Text(suffix)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(AppColors.insetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(focused ? AppColors.accentHighlight.opacity(0.55) : AppColors.separator, lineWidth: 1)
            }
        }
        .onAppear { syncTextFromValue() }
        .onChange(of: value) { _, _ in
            guard !focused else { return }
            syncTextFromValue()
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
    }

    private func syncTextFromValue() {
        if allowsEmpty, value <= 0 {
            text = ""
        } else {
            text = BacktestInputComponents.formatDecimal(value, fractionDigits: fractionDigits)
        }
    }

    private func commit() {
        if allowsEmpty, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            value = 0
            return
        }
        if let parsed = BacktestInputComponents.parseDecimal(text) {
            value = max(allowsEmpty ? 0 : 0.01, parsed)
            syncTextFromValue()
        } else {
            syncTextFromValue()
        }
    }
}

struct BacktestIntField: View {
    let label: String
    let placeholder: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1 ... 999

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.secondaryLabel)

            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .font(.body.monospacedDigit())
                .foregroundStyle(AppColors.label)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(AppColors.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(focused ? AppColors.accentHighlight.opacity(0.55) : AppColors.separator, lineWidth: 1)
                }
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { commit() }
        }
        .onAppear { text = String(value) }
        .onChange(of: value) { _, newValue in
            guard !focused else { return }
            text = String(newValue)
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
    }

    private func commit() {
        if let parsed = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            value = min(max(range.lowerBound, parsed), range.upperBound)
        }
        text = String(value)
    }
}

struct BacktestChipRow<Option: Hashable>: View {
    let options: [(Option, String)]
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = selection == option.0
                Button {
                    selection = option.0
                } label: {
                    Text(option.1)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? AppColors.accentHighlight : AppColors.secondaryLabel)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? AppColors.accentMuted : AppColors.insetSurface)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(isSelected ? AppColors.accentHighlight.opacity(0.35) : AppColors.separator, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

struct BacktestRunButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isLoading ? "Running…" : "Run backtest")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .disabled(isLoading)
    }
}
