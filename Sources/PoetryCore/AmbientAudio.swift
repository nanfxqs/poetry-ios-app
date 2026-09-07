import Foundation
import CryptoKit

public struct AmbientAudio: Equatable {
    public let id: String
    public let sha256: String
    public static let stream = AmbientAudio(id: "swale-v1.wav", sha256: "2f1f2c9472d68e2acd51809bfed4174f46aab419cbd36f85194237af40558766")
    public static let credit = "缓水：Swale flowing into a stream — Siddharth Patil（Ksd5 / Sidpatil），CC0 1.0，Wikimedia Commons。经裁剪、循环交叉淡化及音量处理；仅为阅读情景，不还原创作现场。"
}

/// A file becomes available only after exact manifest verification and atomic installation.
public struct AudioCache {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func file(for audio: AmbientAudio) -> URL? {
        let url = directory.appendingPathComponent(audio.id)
        guard let data = try? Data(contentsOf: url), valid(data, audio) else { return nil }
        return url
    }
    public func install(_ data: Data, for audio: AmbientAudio) throws -> URL {
        guard valid(data, audio) else { throw ContentUpdateError.invalid }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(audio.id)
        try data.write(to: url, options: .atomic)
        return url
    }
    private func valid(_ data: Data, _ audio: AmbientAudio) -> Bool {
        data.count <= 2_000_000 && SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == audio.sha256
    }
}

@MainActor public protocol AmbientAudioPlayer: AnyObject {
    func playLoop(at url: URL) throws
    func stop()
}

/// Own one player, always stop its previous sound before opening another file.
@MainActor public final class AmbientPlayback {
    public private(set) var isPlaying = false
    private let player: AmbientAudioPlayer
    public init(player: AmbientAudioPlayer) { self.player = player }
    public func play(at url: URL) throws {
        stop()
        do { try player.playLoop(at: url); isPlaying = true }
        catch { stop(); throw error }
    }
    public func stop() { player.stop(); isPlaying = false }
}
