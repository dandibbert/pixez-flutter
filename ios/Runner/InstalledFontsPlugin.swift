import Flutter
import UIKit

struct InstalledFontsPlugin {
    static func bind(_ engineBridge: FlutterImplicitEngineBridge) {
        let channel = FlutterMethodChannel(
            name: "com.perol.dev/fonts",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            if call.method == "listFamilies" {
                DispatchQueue.global(qos: .userInitiated).async {
                    let families = UIFont.familyNames.sorted {
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
