import SwiftUI
import UIKit

/// A native UIKit text-input bridge. It keeps iOS autocorrect, international
/// keyboards, dictation and hardware-key handling while forwarding input to Windows.
struct RemoteKeyboardView: UIViewRepresentable {
    @Binding var isFocused: Bool
    let onText: (String) -> Void
    let onKey: (RemoteKeyEvent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onText: onText) }

    func makeUIView(context: Context) -> RemoteTextView {
        let view = RemoteTextView()
        view.delegate = context.coordinator
        view.onKey = onKey
        view.autocorrectionType = .yes
        view.autocapitalizationType = .sentences
        view.smartDashesType = .yes
        view.smartQuotesType = .yes
        view.returnKeyType = .default
        view.text = " "
        view.selectedRange = NSRange(location: 1, length: 0)
        return view
    }

    func updateUIView(_ view: RemoteTextView, context: Context) {
        view.onKey = onKey
        if isFocused, !view.isFirstResponder {
            DispatchQueue.main.async { view.becomeFirstResponder() }
        } else if !isFocused, view.isFirstResponder {
            DispatchQueue.main.async { view.resignFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let onText: (String) -> Void
        init(onText: @escaping (String) -> Void) { self.onText = onText }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text.isEmpty { onText("\u{8}") }
            else { onText(text) }
            textView.text = " "
            textView.selectedRange = NSRange(location: 1, length: 0)
            return false
        }
    }
}

final class RemoteTextView: UITextView {
    var onKey: ((RemoteKeyEvent) -> Void)?

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }
            let modifiers = key.modifierFlags
            let special = Self.specialKey(for: key.keyCode.rawValue)
            let hasChordModifier = !modifiers.intersection([.control, .alternate, .command]).isEmpty
            guard special != nil || hasChordModifier else { continue }
            let name = special ?? key.charactersIgnoringModifiers.lowercased()
            guard !name.isEmpty else { continue }
            onKey?(RemoteKeyEvent(
                key: name,
                control: modifiers.contains(.control),
                alt: modifiers.contains(.alternate),
                shift: modifiers.contains(.shift),
                command: modifiers.contains(.command)
            ))
            handled = true
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    private static func specialKey(for code: Int) -> String? {
        let names: [Int: String] = [
            0x28: "return", 0x29: "escape", 0x2A: "backspace", 0x2B: "tab",
            0x4A: "home", 0x4B: "pageUp", 0x4C: "delete", 0x4D: "end",
            0x4E: "pageDown", 0x4F: "right", 0x50: "left", 0x51: "down", 0x52: "up"
        ]
        if let name = names[code] { return name }
        if (0x3A...0x45).contains(code) { return "f\(code - 0x39)" }
        return nil
    }
}
