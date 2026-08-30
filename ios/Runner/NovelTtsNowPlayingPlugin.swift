import AVFoundation
import Flutter
import MediaPlayer
import UIKit

struct NovelTtsNowPlayingPlugin {
    static let channelName = "com.perol.dev/novel_tts"
    private static var channel: FlutterMethodChannel?

    static func bind(_ engineBridge: FlutterImplicitEngineBridge) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        self.channel = channel
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "start":
                Self.start(Self.info(from: call.arguments))
                result(nil)
            case "update":
                Self.update(Self.info(from: call.arguments))
                result(nil)
            case "stop":
                Self.stop()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        Self.installRemoteCommands()
    }

    private static func info(from arguments: Any?) -> [String: Any] {
        arguments as? [String: Any] ?? [:]
    }

    private static func start(_ info: [String: Any]) {
        activateSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        update(info)
    }

    private static func update(_ info: [String: Any]) {
        let title = string(info["title"])
        let artist = string(info["artist"])
        let subtitle = string(info["subtitle"])
        let isPlaying = info["isPlaying"] as? Bool ?? false
        let durationMs = number(info["durationMs"])
        let positionMs = number(info["positionMs"])
        var nowPlaying: [String: Any] = [
            MPMediaItemPropertyTitle: subtitle.isEmpty ? title : subtitle,
            MPMediaItemPropertyArtist: artist.isEmpty ? title : artist,
            MPMediaItemPropertyAlbumTitle: title,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if durationMs > 0 {
            nowPlaying[MPMediaItemPropertyPlaybackDuration] = durationMs / 1000.0
        }
        if positionMs >= 0 {
            nowPlaying[MPNowPlayingInfoPropertyElapsedPlaybackTime] = positionMs / 1000.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
    }

    private static func stop() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            try? session.setCategory(.playback)
            try? session.setActive(true)
        }
    }

    private static func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.stopCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            emit("play")
            return .success
        }
        center.pauseCommand.addTarget { _ in
            emit("pause")
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            emit("toggle")
            return .success
        }
        center.nextTrackCommand.addTarget { _ in
            emit("next")
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            emit("previous")
            return .success
        }
        center.stopCommand.addTarget { _ in
            emit("stop")
            return .success
        }
    }

    private static func emit(_ method: String) {
        DispatchQueue.main.async {
            channel?.invokeMethod(method, arguments: nil)
        }
    }

    private static func string(_ value: Any?) -> String {
        value as? String ?? ""
    }

    private static func number(_ value: Any?) -> Double {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        return 0
    }
}
