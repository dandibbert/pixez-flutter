import AVFoundation
import Flutter
import MediaPlayer
import UIKit

struct NovelTtsNowPlayingPlugin {
    static let channelName = "com.perol.dev/novel_tts"
    private static var channel: FlutterMethodChannel?
    private static var keepAlivePlayer: AVAudioPlayer?
    private static var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private static var backgroundTaskCount = 0

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
            case "keepAlive":
                Self.startKeepAlive()
                result(nil)
            case "endKeepAlive":
                Self.stopKeepAlive()
                result(nil)
            case "beginBackgroundTask":
                Self.beginBackgroundTask()
                result(nil)
            case "endBackgroundTask":
                Self.endBackgroundTask()
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
        startKeepAlive()
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
        stopKeepAlive()
        endBackgroundTask(force: true)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            try? session.setCategory(.playback)
            try? session.setActive(true)
        }
    }

    private static func startKeepAlive() {
        activateSession()
        if keepAlivePlayer == nil {
            keepAlivePlayer = try? AVAudioPlayer(data: silenceWav())
            keepAlivePlayer?.numberOfLoops = -1
            keepAlivePlayer?.volume = 0.01
            keepAlivePlayer?.prepareToPlay()
        }
        keepAlivePlayer?.play()
    }

    private static func stopKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
    }

    private static func beginBackgroundTask() {
        backgroundTaskCount += 1
        if backgroundTask != .invalid {
            return
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "pixez.novel.tts") {
            Self.endBackgroundTask(force: true)
        }
    }

    private static func endBackgroundTask(force: Bool = false) {
        if !force {
            backgroundTaskCount = max(0, backgroundTaskCount - 1)
            if backgroundTaskCount > 0 {
                return
            }
        } else {
            backgroundTaskCount = 0
        }
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private static func silenceWav() -> Data {
        let sampleRate: UInt32 = 8000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let dataSize = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        var data = Data()
        func appendU32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func appendU16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        appendU32(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendU32(16)
        appendU16(1)
        appendU16(channels)
        appendU32(sampleRate)
        appendU32(sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8))
        appendU16(channels * bitsPerSample / 8)
        appendU16(bitsPerSample)
        data.append(contentsOf: Array("data".utf8))
        appendU32(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
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
