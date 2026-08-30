import ActivityKit
import Flutter
import Foundation

@available(iOS 16.1, *)
struct NovelTtsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var displayText: String
        var page: Int
        var chunkIndex: Int
        var chunkTotal: Int
        var playbackState: String
    }

    var title: String
    var author: String
}

enum NovelTtsLiveActivityPlugin {
    private static var activity: Any?

    static func bind(_ engineBridge: FlutterImplicitEngineBridge) {
        let channel = FlutterMethodChannel(
            name: "com.perol.dev/novel_tts_live_activity",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            guard #available(iOS 16.1, *) else {
                result(false)
                return
            }
            switch call.method {
            case "start":
                start(arguments: call.arguments, result: result)
            case "update":
                update(arguments: call.arguments, result: result)
            case "end":
                end(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    @available(iOS 16.1, *)
    private static func payload(_ arguments: Any?) -> (
        attributes: NovelTtsActivityAttributes,
        state: NovelTtsActivityAttributes.ContentState
    )? {
        guard let values = arguments as? [String: Any],
              let title = values["title"] as? String,
              let author = values["author"] as? String,
              let displayText = values["displayText"] as? String,
              let page = values["page"] as? Int,
              let chunkIndex = values["chunkIndex"] as? Int,
              let chunkTotal = values["chunkTotal"] as? Int,
              let playbackState = values["playbackState"] as? String
        else { return nil }
        return (
            NovelTtsActivityAttributes(title: title, author: author),
            NovelTtsActivityAttributes.ContentState(
                displayText: displayText,
                page: page,
                chunkIndex: chunkIndex,
                chunkTotal: chunkTotal,
                playbackState: playbackState
            )
        )
    }

    @available(iOS 16.1, *)
    private static func start(arguments: Any?, result: @escaping FlutterResult) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let payload = payload(arguments)
        else {
            result(false)
            return
        }
        Task {
            if let current = activity as? Activity<NovelTtsActivityAttributes> {
                await current.end(dismissalPolicy: .immediate)
            }
            do {
                let created = try Activity<NovelTtsActivityAttributes>.request(
                    attributes: payload.attributes,
                    contentState: payload.state,
                    pushType: nil
                )
                activity = created
                result(true)
            } catch {
                result(FlutterError(
                    code: "live_activity_start_failed",
                    message: error.localizedDescription,
                    details: nil
                ))
            }
        }
    }

    @available(iOS 16.1, *)
    private static func update(arguments: Any?, result: @escaping FlutterResult) {
        guard let current = activity as? Activity<NovelTtsActivityAttributes>,
              let payload = payload(arguments)
        else {
            result(false)
            return
        }
        Task {
            await current.update(using: payload.state)
            result(true)
        }
    }

    @available(iOS 16.1, *)
    private static func end(result: @escaping FlutterResult) {
        guard let current = activity as? Activity<NovelTtsActivityAttributes> else {
            result(true)
            return
        }
        Task {
            await current.end(dismissalPolicy: .immediate)
            activity = nil
            result(true)
        }
    }
}
