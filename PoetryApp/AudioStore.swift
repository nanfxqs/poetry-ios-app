import SwiftUI
import AVFoundation
import PoetryCore

@MainActor private final class NativeAmbientPlayer: AmbientAudioPlayer {
    private var player: AVAudioPlayer?
    func playLoop(at url: URL) throws {
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        let next = try AVAudioPlayer(contentsOf: url)
        next.numberOfLoops = -1
        guard next.prepareToPlay(), next.play() else { throw ContentUpdateError.unavailable }
        player = next
    }
    func stop() {
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor final class AudioStore: ObservableObject {
    static let shared = AudioStore()
    @Published private(set) var isPlaying = false
    @Published private(set) var downloading = false
    @Published private(set) var message: String?
    private let playback = AmbientPlayback(player: NativeAmbientPlayer())
    private let cache = AudioCache(directory: URL.applicationSupportDirectory.appendingPathComponent("AmbientAudio", isDirectory: true))
    private var generation = 0
    var downloaded: Bool { cache.file(for: .stream) != nil }
    func stop() { generation += 1; playback.stop(); isPlaying = false }
    func toggle() async {
        guard !downloading else { return }
        if isPlaying { stop(); return }
        let attempt = generation
        message = nil
        do {
            let url: URL
            if let saved = cache.file(for: .stream) { url = saved }
            else {
                guard let credentials = try PoetryServiceSettings.load() else {
                    message = "请先在诗集的个人服务中保存连接，再重试下载。正文仍可阅读。"
                    return
                }
                downloading = true
                defer { downloading = false }
                let data = try await PoetryServiceClient(credentials: credentials).downloadAudio()
                try Task.checkCancellation()
                url = try cache.install(data, for: .stream)
            }
            try Task.checkCancellation()
            guard generation == attempt else { return }
            try playback.play(at: url)
            isPlaying = playback.isPlaying
        } catch {
            stop()
            message = "环境声未能播放，可点按图标重试。正文仍可阅读；未完成或损坏的声音不会播放。"
        }
    }
}
