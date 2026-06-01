import SwiftUI
import UIKit

enum AppKeyboardDoneAccessoryFactory {
    static func makeToolbar() -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .black
        toolbar.isTranslucent = true
        toolbar.tintColor = UIColor(AppColors.accentHighlight)

        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: AppKeyboardDismissHandler.shared,
            action: #selector(AppKeyboardDismissHandler.dismissKeyboard)
        )
        toolbar.items = [spacer, done]
        toolbar.sizeToFit()
        return toolbar
    }
}

extension View {
    /// Fallback Done bar for standard keyboards inside navigation stacks.
    func appKeyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    AppKeyboardDismissHandler.dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.accentHighlight)
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
        field.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.labelFontSize, weight: .regular)
        field.textColor = UIColor(AppColors.label)
        field.tintColor = UIColor(AppColors.accentHighlight)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.inputAccessoryView = AppKeyboardDoneAccessoryFactory.makeToolbar()
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isEditing: Bool

        init(text: Binding<String>, isEditing: Binding<Bool>) {
            _text = text
            _isEditing = isEditing
        }

        @objc func editingChanged(_ field: UITextField) {
            text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isEditing = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            text = textField.text ?? ""
            isEditing = false
        }
    }
}
