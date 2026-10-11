import Flutter
import UIKit

/// Bridges a Flutter text selection to the selection UIKit exposes.
///
/// Shortcuts' "Get Selected Text" action reads the selected range of the
/// foreground app's first-responder text input. Flutter draws [SelectionArea]
/// highlights itself and does not install a UITextInput for them, so the
/// action otherwise returns nothing.
enum SelectedTextPlugin {
    static let channelName = "pixez/selected_text"

    static func bind(_ engineBridge: FlutterImplicitEngineBridge) {
        PixezInstallSelectedTextAccessibility()
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "setSelectedText" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let text = call.arguments as? String ?? ""
            SelectedTextProxy.shared.update(text)
            result(nil)
        }
    }
}

final class SelectedTextProxy {
    static let shared = SelectedTextProxy()

    private let textView = ShortcutSelectedTextView()
    private var current = ""

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reclaimIfNeeded),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    func update(_ text: String) {
        current = text
        guard let window = Self.keyWindow() else {
            textView.remember(text)
            return
        }
        textView.frame = window.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if textView.superview !== window {
            window.addSubview(textView)
        }
        // A real editor already reports its own selection. Taking first
        // responder here would hide the keyboard the user is typing on.
        // The accessibility string is still published so Shortcuts can read it.
        if Self.foreignTextInputIsFirstResponder(in: window) {
            textView.remember(text)
            return
        }
        textView.show(text)
    }

    @objc private func reclaimIfNeeded() {
        guard !current.isEmpty else {
            return
        }
        update(current)
    }

    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    private static func foreignTextInputIsFirstResponder(in window: UIWindow) -> Bool {
        guard let responder = window.pixezFirstResponder() else {
            return false
        }
        if responder is ShortcutSelectedTextView {
            return false
        }
        let name = NSStringFromClass(type(of: responder))
        return name.contains("FlutterTextInput") || responder is UITextField || responder is UITextView
    }
}

/// Read-only stand-in for the Flutter highlight.
///
/// The view holds only the currently selected string, with that whole string
/// selected, and becomes first responder without editing. A real text field
/// keeps the responder while the user is typing.
final class ShortcutSelectedTextView: UITextView {
    private var clearItem: DispatchWorkItem?

    init() {
        super.init(frame: .zero, textContainer: nil)
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        backgroundColor = .clear
        textColor = .clear
        tintColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        dataDetectorTypes = []
        autocorrectionType = .no
        spellCheckingType = .no
        smartDashesType = .no
        smartQuotesType = .no
        smartInsertDeleteType = .no
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
        isAccessibilityElement = true
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// Publishes text while a real editor keeps first responder.
    func remember(_ text: String) {
        clearItem?.cancel()
        if text.isEmpty {
            schedule(text)
            return
        }
        PixezSetSelectedText(text)
        accessibilityValue = text
        self.text = text
        selectedRange = NSRange(location: 0, length: (text as NSString).length)
    }

    func show(_ text: String) {
        schedule(text)
    }

    private func schedule(_ text: String) {
        clearItem?.cancel()
        if text.isEmpty {
            let work = DispatchWorkItem { [weak self] in
                self?.apply("")
            }
            clearItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
            return
        }
        apply(text)
    }

    private func apply(_ text: String) {
        PixezSetSelectedText(text)
        accessibilityValue = text.isEmpty ? nil : text
        if text.isEmpty {
            self.text = ""
            selectedRange = NSRange(location: 0, length: 0)
            if isFirstResponder {
                _ = resignFirstResponder()
            }
            return
        }
        self.text = text
        let range = NSRange(location: 0, length: (text as NSString).length)
        if !isFirstResponder {
            _ = becomeFirstResponder()
        }
        selectedRange = range
        if !isFirstResponder {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.text == text, !self.isFirstResponder else {
                    return
                }
                _ = self.becomeFirstResponder()
                self.selectedRange = range
            }
        }
        dismissEditMenu()
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action == #selector(copy(_:)) && !(text ?? "").isEmpty
    }

    override func copy(_ sender: Any?) {
        guard let selected = selectedText, !selected.isEmpty else {
            return
        }
        UIPasteboard.general.string = selected
    }

    private var selectedText: String? {
        guard let range = selectedTextRange, !range.isEmpty else {
            return nil
        }
        return text(in: range)
    }

    private func dismissEditMenu() {
        if #available(iOS 16.0, *) {
            interactions
                .compactMap { $0 as? UIEditMenuInteraction }
                .forEach { $0.dismissMenu() }
        }
    }
}

private extension UIView {
    func pixezFirstResponder() -> UIResponder? {
        if isFirstResponder {
            return self
        }
        for subview in subviews {
            if let found = subview.pixezFirstResponder() {
                return found
            }
        }
        return nil
    }
}
