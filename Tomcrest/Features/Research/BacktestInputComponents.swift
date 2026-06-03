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
    var onCommit: ((Double) -> Void)? = nil

    @State private var text = ""
    @State private var isEditing = false

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

                DecimalPadTextField(
                    placeholder: placeholder,
                    text: $text,
                    isEditing: $isEditing
                )
                .frame(minHeight: 22)

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
                    .stroke(isEditing ? AppColors.accentHighlight.opacity(0.55) : AppColors.separator, lineWidth: 1)
            }
        }
        .onAppear { syncTextFromValue() }
        .onChange(of: value) { _, _ in
            guard !isEditing else { return }
            syncTextFromValue()
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { commit() }
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
            let previous = value
            value = 0
            if previous != 0 {
                onCommit?(value)
            }
            return
        }
        if let parsed = BacktestInputComponents.parseDecimal(text) {
            let next = max(allowsEmpty ? 0 : 0.01, parsed)
            let previous = value
            value = next
            syncTextFromValue()
            if next != previous {
                onCommit?(next)
            }
        } else {
            syncTextFromValue()
        }
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

struct BacktestOptionToggle: View {
    let title: String
    var footnote: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.label)
                        .multilineTextAlignment(.leading)
                    if let footnote {
                        Text(footnote)
                            .font(.caption2)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                BacktestToggleIndicator(isOn: isOn)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? AppColors.accentMuted : AppColors.insetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isOn ? AppColors.accentHighlight.opacity(0.35) : AppColors.separator,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(BacktestOptionToggleStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct BacktestToggleIndicator: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isOn ? AppColors.accentHighlight.opacity(0.18) : AppColors.secondaryFill.opacity(0.65))
                .frame(width: 22, height: 22)

            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.accentHighlight)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isOn ? AppColors.accentHighlight.opacity(0.5) : AppColors.separator, lineWidth: 1)
        }
    }
}

private struct BacktestOptionToggleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct BacktestRunButton: View {
    var title = "Run backtest"
    var loadingTitle = "Running…"
    var icon = "play.fill"
    let isLoading: Bool
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppColors.accentHighlight)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .frame(width: 14, height: 14)

                Text(isLoading ? loadingTitle : title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isLoading ? AppColors.secondaryLabel : AppLightButtonColors.label)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                (isLoading ? AppColors.secondaryFill : AppLightButtonColors.fill)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(BacktestRunButtonStyle())
        .disabled(isLoading || isDisabled)
    }

    /// Divider + left-aligned run action for the bottom of a controls panel.
    var panelFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AppColors.separator)
                .padding(.top, 2)

            self
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct BacktestRunButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
