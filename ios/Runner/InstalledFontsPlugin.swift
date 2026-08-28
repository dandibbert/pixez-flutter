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
        for url in availableFontURLs() {
            for family in families(at: url) {
                names.insert(family)
            }
        }
        return names
            .filter { !$0.isEmpty && !$0.hasPrefix(".") && !$0.hasPrefix("@") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func loadFamily(_ family: String) -> Data? {
        var systemMatch: Data?
        for url in availableFontURLs() {
            guard families(at: url).contains(family) else { continue }
            guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
            if isUserInstalled(url) {
                return data
            }
            systemMatch = data
        }
        if let systemMatch {
            return systemMatch
        }
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: family,
        ] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, 0, nil)
        if let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL,
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            return data
        }
        return nil
    }

    static func availableFontURLs() -> [URL] {
        (CTFontManagerCopyAvailableFontURLs() as? [URL]) ?? []
    }

    static func families(at url: URL) -> [String] {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
                as? [CTFontDescriptor] else {
            return []
        }
        return descriptors.compactMap { descriptor in
            CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
        }
    }

    static func isUserInstalled(_ url: URL) -> Bool {
        let path = url.path
        if path.contains("/System/") || path.hasPrefix("/System/") {
            return false
        }
        if path.contains("/usr/share") {
            return false
        }
        return true
    }
}
