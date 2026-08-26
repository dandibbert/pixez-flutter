import Cocoa
import FlutterMacOS

struct InstalledFontsPlugin {
    static func bind(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.perol.dev/fonts",
            binaryMessenger: controller.engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            if call.method == "listFamilies" {
                DispatchQueue.global(qos: .userInitiated).async {
                    let families = NSFontManager.shared.availableFontFamilies.sorted {
                        $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                    }
                    DispatchQueue.main.async {
                        result(families)
                    }
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
