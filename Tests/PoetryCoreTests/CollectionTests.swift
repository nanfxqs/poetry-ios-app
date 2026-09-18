import Foundation
import XCTest
@testable import PoetryCore

final class CollectionTests: XCTestCase {
    func testCollectionPersistsAcrossPagesAndRestartWithIdempotentSaveAndRemoval() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("collection.sqlite")
        let today = try PoetryApplication(databaseURL: url)
        let poems = try today.allPoems()
        try today.saveFavorite(poems[0])
        let collection = try PoetryApplication(databaseURL: url)
        XCTAssertTrue(try collection.isFavorite(id: poems[0].id))
        try collection.saveFavorite(poems[1])
        try today.saveFavorite(poems[0])
        XCTAssertEqual(try today.favoritePoems().map(\.id), [poems[1].id, poems[0].id])
        let reopened = try PoetryApplication(databaseURL: url, seed: [])
        XCTAssertEqual(try reopened.favoritePoems().map(\.poem), [poems[1], poems[0]])
        try reopened.removeFavorite(id: poems[1].id)
        try reopened.removeFavorite(id: poems[1].id)
        XCTAssertFalse(try today.isFavorite(id: poems[1].id))
        XCTAssertEqual(try collection.favoritePoems().count, 1)
        XCTAssertEqual(try collection.readPoem(id: poems[1].id), poems[1])
        try collection.removeFavorite(id: poems[0].id)
        XCTAssertTrue(try PoetryApplication(databaseURL: url).favoritePoems().isEmpty)
    }

    func testCollectionSearchesOnlySavedTitlesPoetsAndLinesAndResavingMovesToFront() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = Poem(id: "first", title: "山居", poetID: "wang-wei", poet: "王维", lines: ["明月松间照"], sources: [])
        let second = Poem(id: "second", title: "送别", poetID: "li-bai", poet: "李白", lines: ["孤帆远影"], sources: [])
        let third = Poem(id: "third", title: "未收藏", poetID: "wang-wei", poet: "王维", lines: ["明月"], sources: [])
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("collection.sqlite"), seed: [first, second, third])
        try app.saveFavorite(first, at: Date(timeIntervalSince1970: 100))
        // Logical save order survives a backwards wall clock or equal timestamps.
        try app.saveFavorite(second, at: Date(timeIntervalSince1970: 50))
        XCTAssertEqual(try app.favoritePoems().map(\.id), [second.id, first.id])
        for query in ["山居", "王维", "松间", " 明月 "] { XCTAssertEqual(try app.favoritePoems(search: query).map(\.id), [first.id]) }
        XCTAssertTrue(try app.favoritePoems(search: "不存在").isEmpty)
        try app.removeFavorite(id: first.id)
        try app.saveFavorite(first)
        XCTAssertEqual(try app.favoritePoems().map(\.id), [first.id, second.id])
    }

    func testSavedSnapshotIsIndependentOfContentAvailability() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("collection.sqlite"), seed: [])
        let historical = Poem(id: "removed-from-catalog", title: "旧藏", poetID: "poet", poet: "诗人", lines: ["全文仍在"], sources: [])
        try app.saveFavorite(historical)
        XCTAssertNil(try app.readPoem(id: historical.id))
        XCTAssertEqual(try app.favoritePoems().first?.poem, historical)
    }
}
