import CoreText
import Flutter
import UIKit

struct InstalledFontsPlugin {
    static func bind(_ engineBridge: FlutterImplicitEngineBridge) {
        let channel = FlutterMethodChannel(
            name: "com.perol.dev/fonts",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "listFamilies":
                DispatchQueue.global(qos: .userInitiated).async {
                    let families = Self.listFamilies()
                    DispatchQueue.main.async {
                        result(families)
                    }
                }
            case "loadFamily":
                let family = Self.familyArgument(call.arguments)
                DispatchQueue.global(qos: .userInitiated).async {
                    let data = family.flatMap { Self.loadFamily($0) }
                    DispatchQueue.main.async {
                        if let data {
                            result(FlutterStandardTypedData(bytes: data))
                        } else {
                            result(nil)
                        }
                    }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    static func familyArgument(_ arguments: Any?) -> String? {
        if let family = arguments as? String, !family.isEmpty {
            return family
        }
        if let map = arguments as? [String: Any],
           let family = map["family"] as? String,
           !family.isEmpty {
            return family
        }
        return nil
    }

    static func listFamilies() -> [String] {
        var names = Set<String>()
        names.formUnion(UIFont.familyNames)
        if let ctNames = CTFontManagerCopyAvailableFontFamilyNames() as? [String] {
            names.formUnion(ctNames)
        }
        for descriptor in registeredDescriptors() {
            if let family = CTFontDescriptorCopyAttribute(
                descriptor,
                kCTFontFamilyNameAttribute
            ) as? String {
                names.insert(family)
            }
        }
        return names
            .filter { !$0.isEmpty && !$0.hasPrefix(".") && !$0.hasPrefix("@") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func loadFamily(_ family: String) -> Data? {
        for descriptor in registeredDescriptors() {
            let name = CTFontDescriptorCopyAttribute(
                descriptor,
                kCTFontFamilyNameAttribute
            ) as? String
            guard name == family else { continue }
            if let data = data(from: descriptor) {
                return data
            }
        }
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: family,
        ] as CFDictionary)
        return data(from: descriptor)
    }

    /// User-installed fonts from configuration profiles / the Fonts app.
    /// `CTFontManagerCopyAvailableFontURLs` is macOS-only.
    static func registeredDescriptors() -> [CTFontDescriptor] {
        var descriptors: [CTFontDescriptor] = []
        let scopes: [CTFontManagerScope] = [.user, .process]
        for scope in scopes {
            if let copied = CTFontManagerCopyRegisteredFontDescriptors(scope, true)
                as? [CTFontDescriptor] {
                descriptors.append(contentsOf: copied)
            }
        }
        return descriptors
    }

    static func data(from descriptor: CTFontDescriptor) -> Data? {
        if let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL,
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            return data
        }
        let font = CTFontCreateWithFontDescriptor(descriptor, 0, nil)
        if let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL,
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            return data
        }
        return nil
    }
}
