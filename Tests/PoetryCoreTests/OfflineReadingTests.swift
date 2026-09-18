import Foundation
import XCTest
@testable import PoetryCore

final class OfflineReadingTests: XCTestCase {
    func testFirstInstallReadsCompleteBundledPoemAndSourcesAfterRestartWithoutSeed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("reader.sqlite")
        var app: PoetryApplication? = try PoetryApplication(databaseURL: url)
        let poems = try XCTUnwrap(app).allPoems()
        XCTAssertEqual(poems.count, 6)
        let poem = try XCTUnwrap(app?.readPoem(id: "huanghelou-song-meng-haoran"))
        XCTAssertEqual(poem.lines.joined(), "故人西辞黄鹤楼，烟花三月下扬州。孤帆远影碧空尽，唯见长江天际流。")
        XCTAssertFalse(poem.sources.isEmpty)
        XCTAssertTrue(poem.sources[0].license.contains("公有领域"))
        XCTAssertNil(poem.background)
        app = nil
        let reopened = try PoetryApplication(databaseURL: url, seed: [])
        XCTAssertEqual(try reopened.readPoem(id: poem.id), poem)
        XCTAssertEqual(try reopened.allPoems(), poems)
    }
    func testLongTitleAndPoemAreReturnedWithoutTruncation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let poem = Poem(id: "long", title: String(repeating: "长题", count: 40), poetID: "test", poet: "测试", lines: Array(repeating: "长诗正文完整可读。", count: 100), sources: [])
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("reader.sqlite"), seed: [poem])
        XCTAssertEqual(try app.readPoem(id: "long"), poem)
    }
}
