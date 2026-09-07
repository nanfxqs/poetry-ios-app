import Foundation
import XCTest
import CryptoKit
@testable import PoetryCore

final class ContentUpdateTests: XCTestCase {
    private func package(_ poems: [Poem], version: Int = 1, missingAuthor: Bool = false) throws -> Data {
        let objects = try JSONSerialization.jsonObject(with: JSONEncoder().encode(poems))
        let sources = try JSONSerialization.jsonObject(with: JSONEncoder().encode(poems[0].sources))
        let poets: [[String: Any]] = missingAuthor ? [] : Set(poems.map(\.poetID)).map { ["id": $0, "name": $0, "dynasty": "唐", "sources": sources] }
        let payload = String(decoding: try JSONSerialization.data(withJSONObject: ["poems": objects, "catalogs": ["poets": poets, "places": [], "placeAssociations": [], "lifeEvents": [], "tags": [:]]]), as: UTF8.self)
        return try JSONEncoder().encode(ContentPackage(version: version, sha256: SHA256.hash(data: Data(payload.utf8)).map { String(format: "%02x", $0) }.joined(), payload: payload))
    }
    func testUpdatePreservesSavedDayAndRemovedFavoriteAcrossRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("poetry.sqlite")
        let app = try PoetryApplication(databaseURL: url)
        let now = Date()
        let selected = try XCTUnwrap(app.dailyPoem(at: now))
        try app.saveFavorite(selected)
        let remaining = try app.allPoems().filter { $0.id != selected.id }
        try app.installContentPackage(data: package(remaining))
        let reopened = try PoetryApplication(databaseURL: url)
        XCTAssertEqual(try reopened.allPoems(), remaining)
        XCTAssertEqual(try reopened.dailyPoem(at: now), selected)
        XCTAssertEqual(try reopened.favoritePoems().first?.poem, selected)
        XCTAssertEqual(try reopened.contentVersion(), 1)
        XCTAssertTrue(try reopened.contentTags().isEmpty)
        XCTAssertThrowsError(try reopened.installContentPackage(data: package(remaining)))
    }
    func testCorruptInterruptedDanglingAndFailedTransactionRetainEverything() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("poetry.sqlite"))
        let before = try app.allPoems()
        let now = Date()
        let selected = try XCTUnwrap(app.dailyPoem(at: now))
        try app.saveFavorite(selected)
        let good = try package(Array(before.dropFirst()))
        let corrupt = try JSONEncoder().encode(ContentPackage(version: 1, sha256: "wrong", payload: "{}"))
        for bytes in [Data(good.prefix(good.count / 2)), corrupt, try package(before, missingAuthor: true)] {
            XCTAssertThrowsError(try app.installContentPackage(data: bytes))
        }
        // Real SQLite write failure after the catalogs have begun switching.
        try app.database.execute("CREATE TRIGGER refuse_content BEFORE DELETE ON poems BEGIN SELECT RAISE(ABORT, 'simulated disk write failure'); END")
        XCTAssertThrowsError(try app.installContentPackage(data: good))
        XCTAssertEqual(try app.allPoems(), before)
        XCTAssertEqual(try app.dailyPoem(at: now), selected)
        XCTAssertEqual(try app.favoritePoems().first?.poem, selected)
        XCTAssertEqual(try app.contentVersion(), 0)
    }
}
