// Each icon's sound is rendered ahead of time by the same synthesis as the web
// runtime, already placed between the two speakers along the path its moving
// mass travels, and ships as a small .m4a. Here it is only played: at the
// chosen volume, and a little softer for quick repeated taps.
import AVFoundation
import Foundation

@MainActor
public final class JiggiconsAudio {
    public static let shared = JiggiconsAudio()

    /// Volume for every icon sound, 0 to 1.
    public var volume: Double = 1 {
        didSet { volume = min(1, max(0, volume)) }
    }

    // All AVAudioSession and AVAudioPlayer work runs on a dedicated serial
    // background queue so preparing, activating, playing or stopping audio
    // never blocks the main thread or triggers Thread Performance Checker warnings.
    private let queue = DispatchQueue(label: "com.jiggicons.audio", qos: .userInitiated)
    private let worker = Worker()
    private var lastTap = -Double.infinity

    /// Quick repeated taps play softer, so a burst of taps never shouts.
    nonisolated static func gain(forInterval seconds: Double) -> Double {
        let t = min(1, max(0, (seconds - 0.075) / 0.48))
        return 0.42 + 0.58 * t * t * (3 - 2 * t)
    }

    /// Loads a cue off the main thread so its first play starts at once.
    public func preload(_ icon: JiggiconData, variant: JiggiconVariant) {
        guard let key = icon.soundKey(for: variant) else { return }
        let worker = self.worker
        queue.async { worker.preload(key: key) }
    }

    /// Plays an icon's sound. With `overlap` it plays beside a sound still
    /// ringing instead of cutting it off.
    @discardableResult
    public func play(_ icon: JiggiconData, variant: JiggiconVariant = .outline, volume level: Double = 1, overlap: Bool = false) -> Bool {
        guard volume > 0, level > 0, let key = icon.soundKey(for: variant) else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        let gain = Float(Self.gain(forInterval: now - lastTap) * volume * min(1, level))
        lastTap = now
        let worker = self.worker
        queue.async { worker.play(key: key, gain: gain, overlap: overlap) }
        return true
    }

    public func stop() {
        let worker = self.worker
        queue.async { worker.stop() }
    }

    // Confined exclusively to `queue`.
    private final class Worker: @unchecked Sendable {
        private var players: [String: AVAudioPlayer] = [:]
        private var current: AVAudioPlayer?
        private var sessionReady = false

        func preload(key: String) {
            _ = player(for: key)
        }

        func play(key: String, gain: Float, overlap: Bool) {
            guard let player = player(for: key) else { return }
            if !overlap, let current, current !== player { current.stop() }
            player.volume = gain
            player.currentTime = 0
            player.play()
            current = player
        }

        func stop() {
            current?.stop()
            current = nil
        }

        private func player(for key: String) -> AVAudioPlayer? {
            if let player = players[key] { return player }
            prepareSession()
            guard let url = Jiggicons.soundURL(key), let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.prepareToPlay()
            players[key] = player
            return player
        }

        // Icon sounds are interface sounds: they mix with the user's music and
        // stay quiet when the ring/silent switch is set to silent.
        private func prepareSession() {
            guard !sessionReady else { return }
            sessionReady = true
            #if os(iOS) || os(tvOS) || os(visionOS)
            let session = AVAudioSession.sharedInstance()
            if session.category != .ambient && session.category != .playback && session.category != .playAndRecord {
                try? session.setCategory(.ambient, options: [.mixWithOthers])
            }
            #endif
        }
    }
}
