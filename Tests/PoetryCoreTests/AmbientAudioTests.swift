import XCTest
import CryptoKit
@testable import PoetryCore

final class AmbientAudioTests: XCTestCase {
    func testOnlyCompleteVerifiedDownloadSurvivesRestartAndCorruptionIsUnavailable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AudioCache(directory: directory)
        let data = Data("complete downloaded recording".utf8)
        let asset = AmbientAudio(id: "fixture.wav", sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
        XCTAssertNil(cache.file(for: asset))
        XCTAssertThrowsError(try cache.install(data.dropLast(), for: asset))
        XCTAssertNil(cache.file(for: asset))
        let saved = try cache.install(data, for: asset)
        XCTAssertEqual(AudioCache(directory: directory).file(for: asset), saved)
        XCTAssertThrowsError(try cache.install(Data(), for: asset))
        XCTAssertEqual(cache.file(for: asset), saved)
        try Data("corrupt".utf8).write(to: saved)
        XCTAssertNil(cache.file(for: asset))
        _ = try cache.install(data, for: asset)
        XCTAssertNotNil(cache.file(for: asset))
    }
    @MainActor func testDefaultOffSwitchStopsPreviousAndPlaybackFailureRemainsStopped() throws {
        let player = Player()
        let playback = AmbientPlayback(player: player)
        XCTAssertFalse(playback.isPlaying)
        XCTAssertEqual(player.active, 0)
        try playback.play(at: URL(fileURLWithPath: "/one.wav"))
        try playback.play(at: URL(fileURLWithPath: "/two.wav"))
        XCTAssertTrue(playback.isPlaying)
        XCTAssertEqual(player.maximumActive, 1)
        playback.stop()
        XCTAssertEqual(player.active, 0)
        player.fail = true
        XCTAssertThrowsError(try playback.play(at: URL(fileURLWithPath: "/bad.wav")))
        XCTAssertFalse(playback.isPlaying)
        XCTAssertEqual(player.active, 0)
    }
}
@MainActor private final class Player: AmbientAudioPlayer {
    var active = 0, maximumActive = 0
    var fail = false
    func playLoop(at url: URL) throws {
        if fail { throw ContentUpdateError.unavailable }
        active += 1; maximumActive = max(maximumActive, active)
    }
    func stop() { active = 0 }
}
