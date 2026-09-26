import Flutter
import UIKit

/// Publishes the Flutter highlight where Shortcuts can read it.
///
/// "Get Selected Text" asks the foreground view for its selected text. A
/// Flutter SelectionArea never becomes that view, so the runner keeps the
/// latest plain-text highlight and answers from FlutterView.
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

    private var clearItem: DispatchWorkItem?

    private init() {}

    func update(_ text: String) {
        clearItem?.cancel()
        if text.isEmpty {
            let work = DispatchWorkItem {
                PixezSetSelectedText("")
            }
            clearItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
            return
        }
        PixezSetSelectedText(text)
    }
}
