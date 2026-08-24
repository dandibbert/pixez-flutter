//
//  Tinker.swift
//  Tinker
//
//  Created by Perol Notsf on 2024/7/8.
//

import AppIntents
import ImageIO
import SwiftUI
import UIKit
import WidgetKit

struct Provider: TimelineProvider {
    private static let refreshInterval: TimeInterval = 6 * 60 * 60
    private static let requestTimeout: TimeInterval = 20
    private static let minimumImageDimension: CGFloat = 256
    private static let maximumImageDimension: CGFloat = 1024

    var placeHolderEntry: SimpleEntry {
        return SimpleEntry(date: .now, uiImage: nil, id: 1, illustId: 1, userId: 1, pictureUrl: "https://pixiv.net//", title: "No content available", userName: ":(", time: 0, type: "empty")
    }

    func placeholder(in context: Context) -> SimpleEntry {
        placeHolderEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = placeHolderEntry
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let refreshDate = Date().addingTimeInterval(Self.refreshInterval)
        let result = TimelineResult(refreshDate: refreshDate, completion: completion)
        let maxPixelSize = Self.targetImageDimension(for: context)

        DispatchQueue.global(qos: .utility).async {
            guard let first = AppWidgetDBManager.fetch().first,
                  let folder = AppWidgetDBManager.illustFolder()
            else {
                result.complete(with: placeHolderEntry)
                return
            }

            let sourceUrl = first.largeUrl ?? first.pictureUrl
            guard let fileURL = URL(string: sourceUrl) else {
                result.complete(with: placeHolderEntry)
                return
            }

            let fileExtension = fileURL.pathExtension.isEmpty
                ? "img"
                : fileURL.pathExtension.lowercased()
            let pictureURL = folder.appendingPathComponent("\(first.illustId).\(fileExtension)")

            if FileManager.default.fileExists(atPath: pictureURL.path) {
                if let image = Self.downsampledImage(at: pictureURL, maxPixelSize: maxPixelSize) {
                    result.complete(with: first.toSimple(uiImage: image))
                    return
                }
                try? FileManager.default.removeItem(at: pictureURL)
            }

            var request = URLRequest(
                url: fileURL,
                cachePolicy: .returnCacheDataElseLoad,
                timeoutInterval: Self.requestTimeout
            )
            request.setValue("https://app-api.pixiv.net/", forHTTPHeaderField: "referer")
            request.setValue("PixivIOSApp/5.8.0", forHTTPHeaderField: "User-Agent")

            URLSession.shared.downloadTask(with: request) { temporaryURL, response, error in
                guard error == nil,
                      let temporaryURL,
                      let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode)
                else {
                    result.complete(with: placeHolderEntry)
                    return
                }

                do {
                    if !FileManager.default.fileExists(atPath: pictureURL.path) {
                        try FileManager.default.moveItem(at: temporaryURL, to: pictureURL)
                    }
                    guard let image = Self.downsampledImage(
                        at: pictureURL,
                        maxPixelSize: maxPixelSize
                    ) else {
                        try? FileManager.default.removeItem(at: pictureURL)
                        result.complete(with: placeHolderEntry)
                        return
                    }
                    result.complete(with: first.toSimple(uiImage: image))
                } catch {
                    print("Error:\(error)")
                    result.complete(with: placeHolderEntry)
                }
            }.resume()
        }
    }

    private static func targetImageDimension(for context: Context) -> CGFloat {
        let displayDimension = max(context.displaySize.width, context.displaySize.height)
        let physicalDimension = ceil(displayDimension * UIScreen.main.scale)
        return min(max(physicalDimension, minimumImageDimension), maximumImageDimension)
    }

    private static func downsampledImage(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(ceil(maxPixelSize)),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}

private final class TimelineResult {
    private let refreshDate: Date
    private let completion: (Timeline<SimpleEntry>) -> Void
    private let lock = NSLock()
    private var completed = false

    init(refreshDate: Date, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        self.refreshDate = refreshDate
        self.completion = completion
    }

    func complete(with entry: SimpleEntry) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        lock.unlock()
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

extension AppWidgetIllust {
    func toSimple(uiImage: UIImage) -> SimpleEntry {
        SimpleEntry(date: .now, uiImage: uiImage, id: id, illustId: illustId, userId: userId, pictureUrl: pictureUrl, title: title, userName: userName, time: time, type: type)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let uiImage: UIImage?
    let id: Int
    let illustId: Int
    let userId: Int
    let pictureUrl: String
    let title: String?
    let userName: String?
    let time: Int
    let type: String
}

struct TinkerEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        buildContent()
    }

    @ViewBuilder func buildContent() -> some View {
        GeometryReader { red in
            ZStack {
                if entry.type != "empty", let uiImage = entry.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: red.size.width, height: red.size.height, alignment: .center)
                }
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(entry.title ?? "")")
                                .font(.title3)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(radius: 5, x: 0, y: 5)
                            Text("@\(entry.userName ?? "")")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(radius: 5, x: 0, y: 5)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.black.opacity(0.0), .black.opacity(0.4)]), startPoint: .top, endPoint: .bottom)
                    )
                }
            }.frame(width: red.size.width, height: red.size.height, alignment: .center)
        }.widgetURL(URL(string: entry.type == "empty" ? "pixez://pixiv.net" : "pixez://pixiv.net/artworks/\(entry.illustId)"))
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SuperCharge: AppIntent {
    static var title: LocalizedStringResource = "Refresh recommend illust"
    static var description = IntentDescription("Refresh recommend illust")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct Tinker: Widget {
    let kind: String = "Tinker"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ZStack {
                    Color.clear
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(entry.title ?? "")")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .shadow(radius: 5, x: 0, y: 5)
                                Text("@\(entry.userName ?? "")")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .shadow(radius: 5, x: 0, y: 5)
                            }
                            Spacer()
                        }
                    }
                    VStack {
                        HStack(alignment: .top) {
                            Spacer()
                            Button(intent: SuperCharge()) {
                                Image(systemName: "arrow.clockwise")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                        }
                        Spacer()
                    }
                }
                .widgetURL(URL(string: entry.type == "empty" ? "pixez://pixiv.net" : "pixez://pixiv.net/artworks/\(entry.illustId)"))
                .containerBackground(for: .widget) {
                    ZStack {
                        if let image = entry.uiImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                }
            } else {
                TinkerEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct Tinker_Previews: PreviewProvider {
    static var previews: some View {
        let entry = SimpleEntry(date: .now, uiImage: nil, id: 1, illustId: 1, userId: 1, pictureUrl: "https://pixiv.net//", title: "Title", userName: "User", time: 0, type: "")
        TinkerEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
