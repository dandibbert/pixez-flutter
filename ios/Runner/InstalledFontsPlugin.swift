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
                result(UIFont.familyNames.sorted {
                    $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                })
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
