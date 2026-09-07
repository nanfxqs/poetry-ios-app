import AVFoundation
import SwiftUI
import PoetryCore

struct AudioButton: View {
    @ObservedObject private var audio = AudioStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var details = false
    var body: some View {
        Button {
            Task { await audio.toggle(); if audio.message != nil { details = true } }
        } label: {
            Image(systemName: audio.downloading ? "arrow.down.circle" : audio.isPlaying ? "speaker.wave.2" : "speaker.slash")
                .frame(width: 44, height: 44)
        }
        .disabled(audio.downloading)
        .accessibilityLabel(audio.downloading ? "正在下载缓水环境声" : audio.isPlaying ? "停止环境声" : audio.downloaded ? "播放缓水环境声" : "下载并播放缓水环境声")
        .accessibilityIdentifier("ambientAudioButton")
        .contextMenu { Button("环境声素材说明") { details = true } }
        .sheet(isPresented: $details) {
            NavigationStack {
                Form {
                    if let message = audio.message { Text(message) }
                    Text(AmbientAudio.credit)
                    Link("原始声音与许可", destination: URL(string: "https://commons.wikimedia.org/wiki/File:Swale.ogg")!)
                    Text("默认关闭。下载完成后可离线播放。")
                }.navigationTitle("环境声").toolbar { Button("完成") { details = false } }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { audio.stop() } }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in audio.stop() }
    }
}
