import SwiftUI
import UIKit

enum AppKeyboardDoneAccessoryFactory {
    static func makeToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.barStyle = .black
        toolbar.isTranslucent = true
        toolbar.tintColor = UIColor(AppColors.accentHighlight)
        toolbar.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(customView: makeDoneButton())
        toolbar.items = [spacer, done]
        toolbar.sizeToFit()
        return toolbar
    }

    private static func makeDoneButton() -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = "Done"
        config.baseForegroundColor = UIColor(AppColors.accentHighlight)
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 17, weight: .semibold)
            return outgoing
        }
        button.configuration = config
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addAction(
            UIAction { _ in AppKeyboardDismissHandler.dismiss() },
            for: .touchUpInside
        )
        return button
    }
}

extension View {
    /// Fallback Done bar for standard keyboards inside navigation stacks.
    func appKeyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Button("Done") {
                        AppKeyboardDismissHandler.dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Decimal-pad input with a guaranteed Done accessory — SwiftUI keyboard toolbars do not
/// attach reliably to `.decimalPad` fields nested in scroll/tab content.
struct DecimalPadTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isEditing: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isEditing: $isEditing)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.keyboardType = .decimalPad
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.font = AppFont.uiJetBrainsMono(size: UIFont.labelFontSize, weight: .regular)
        field.textColor = UIColor(AppColors.label)
        field.tintColor = UIColor(AppColors.accentHighlight)
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        field.inputAccessoryView = AppKeyboardDoneAccessoryFactory.makeToolbar()
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.updateBindings(text: $text, isEditing: $isEditing)

        if uiView.text != text {
            uiView.text = text
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }
    }

    static func dismantleUIView(_ uiView: UITextField, coordinator: Coordinator) {
        uiView.resignFirstResponder()
        coordinator.invalidate()
        uiView.delegate = nil
        uiView.inputAccessoryView = nil
        uiView.removeTarget(
            coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private var text: Binding<String>
        private var isEditing: Binding<Bool>
        private var isLive = true

        init(text: Binding<String>, isEditing: Binding<Bool>) {
            self.text = text
            self.isEditing = isEditing
        }

        func updateBindings(text: Binding<String>, isEditing: Binding<Bool>) {
            guard isLive else { return }
            self.text = text
            self.isEditing = isEditing
        }

        func invalidate() {
            isLive = false
        }

        @objc func editingChanged(_ field: UITextField) {
            guard isLive else { return }
            text.wrappedValue = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            guard isLive else { return }
            isEditing.wrappedValue = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            guard isLive else { return }
            text.wrappedValue = textField.text ?? ""
            isEditing.wrappedValue = false
        }
    }
}
