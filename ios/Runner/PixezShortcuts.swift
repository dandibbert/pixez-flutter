//
//  PixezShortcuts.swift
//  Runner
//
//  Shortcuts and Spotlight actions. Each one turns its input into a deep link
//  and hands it to DeepLinkPlugin, so they open exactly what the same link
//  opens.
//

import AppIntents
import Foundation

@available(iOS 16.0, *)
enum PixezShortcutError: Error, CustomLocalizedStringResourceConvertible {
    case notALink
    case badId
    case emptyKeyword

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notALink:
            return "No pixiv link was found in the text."
        case .badId:
            return "The ID must be a positive number."
        case .emptyKeyword:
            return "Enter a keyword to search for."
        }
    }
}

@available(iOS 16.0, *)
enum PixezShortcutLinks {
    /// Finds the first link in [text]: a pixez://, pixev://, pixiv:// or web
    /// link, or a bare pixiv.net / pixiv.me address. Text around it, such as
    /// a shared title, is ignored.
    static func link(in text: String) -> String? {
        let pattern = #"(?i)\b(?:pixez|pixev|pixiv|https?)://[^\s<>"]+|\b(?:(?:www|m)\.)?pixiv\.(?:net|me)/[^\s<>"]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let found = Range(match.range, in: text) else {
            return nil
        }
        var link = String(text[found])
        // Punctuation that ends a sentence is not part of the link.
        let trailing = CharacterSet(charactersIn: ".,;:!?)]}」』。，、！？")
        while let last = link.unicodeScalars.last, trailing.contains(last) {
            link.unicodeScalars.removeLast()
        }
        if !link.contains("://") {
            link = "https://" + link
        }
        return URL(string: link) == nil ? nil : link
    }

    static func searchLink(_ keyword: String, novels: Bool) -> String? {
        var components = URLComponents()
        components.scheme = "pixez"
        components.host = "search"
        components.path = novels ? "/novel" : ""
        components.queryItems = [URLQueryItem(name: "word", value: keyword)]
        return components.url?.absoluteString
    }

    @MainActor
    static func open(_ link: String) {
        DeepLinkPlugin.shared.receive(link: link)
    }

    @MainActor
    static func open(id: Int, _ build: (Int) -> String) throws {
        guard id > 0 else { throw PixezShortcutError.badId }
        open(build(id))
    }

    @MainActor
    static func search(_ keyword: String, novels: Bool) throws {
        let word = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, let link = searchLink(word, novels: novels) else {
            throw PixezShortcutError.emptyKeyword
        }
        open(link)
    }
}

@available(iOS 16.0, *)
struct OpenPixivLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open pixiv Link"
    static let description: IntentDescription? = IntentDescription(
        "Opens a pixiv link in PixEz: illusts, novels, users, series, tag pages and pixez:// links. Text around the link is ignored."
    )
    static let openAppWhenRun = true

    @Parameter(title: "Link")
    var link: String

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let url = PixezShortcutLinks.link(in: link) else {
            throw PixezShortcutError.notALink
        }
        PixezShortcutLinks.open(url)
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenIllustIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Illust"
    static let description: IntentDescription? = IntentDescription("Opens an illust or manga by its ID.")
    static let openAppWhenRun = true

    @Parameter(title: "Illust ID")
    var id: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        try PixezShortcutLinks.open(id: id) { "pixez://www.pixiv.net/artworks/\($0)" }
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenNovelIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Novel"
    static let description: IntentDescription? = IntentDescription("Opens a novel by its ID.")
    static let openAppWhenRun = true

    @Parameter(title: "Novel ID")
    var id: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        try PixezShortcutLinks.open(id: id) { "pixez://novel/\($0)" }
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenUserIntent: AppIntent {
    static let title: LocalizedStringResource = "Open User"
    static let description: IntentDescription? = IntentDescription("Opens a user's profile by their ID.")
    static let openAppWhenRun = true

    @Parameter(title: "User ID")
    var id: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        try PixezShortcutLinks.open(id: id) { "pixez://www.pixiv.net/users/\($0)" }
        return .result()
    }
}

@available(iOS 16.0, *)
struct SearchIllustsIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Illusts"
    static let description: IntentDescription? = IntentDescription("Searches illusts and manga for a keyword or tag.")
    static let openAppWhenRun = true

    @Parameter(title: "Keyword")
    var keyword: String

    @MainActor
    func perform() async throws -> some IntentResult {
        try PixezShortcutLinks.search(keyword, novels: false)
        return .result()
    }
}

@available(iOS 16.0, *)
struct SearchNovelsIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Novels"
    static let description: IntentDescription? = IntentDescription("Searches novels for a keyword or tag.")
    static let openAppWhenRun = true

    @Parameter(title: "Keyword")
    var keyword: String

    @MainActor
    func perform() async throws -> some IntentResult {
        try PixezShortcutLinks.search(keyword, novels: true)
        return .result()
    }
}

/// Makes the actions show up in Spotlight and Siri without setting up a
/// shortcut first. The value each one needs is asked for when it runs.
@available(iOS 16.0, *)
struct PixezShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchIllustsIntent(),
            phrases: ["Search illusts in \(.applicationName)"]
        )
        AppShortcut(
            intent: SearchNovelsIntent(),
            phrases: ["Search novels in \(.applicationName)"]
        )
        AppShortcut(
            intent: OpenPixivLinkIntent(),
            phrases: ["Open pixiv link in \(.applicationName)"]
        )
        AppShortcut(
            intent: OpenIllustIntent(),
            phrases: ["Open illust in \(.applicationName)"]
        )
        AppShortcut(
            intent: OpenNovelIntent(),
            phrases: ["Open novel in \(.applicationName)"]
        )
        AppShortcut(
            intent: OpenUserIntent(),
            phrases: ["Open user in \(.applicationName)"]
        )
    }
}
