import Foundation
import XCTest
@testable import PoetryCore

final class ExplorationTests: XCTestCase {
    func testGroupsIntersectWhileValuesWithinGroupAreAlternatives() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let poems = [
            Poem(id: "a", title: "月夜", poetID: "li", poet: "李白", lines: ["举头望明月"], sources: []),
            Poem(id: "b", title: "春日", poetID: "du", poet: "杜甫", lines: ["春风"], sources: []),
            Poem(id: "c", title: "秋月", poetID: "wang", poet: "王维", lines: ["明月松间照"], sources: [])
        ]
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("search.sqlite"), seed: poems)
        let tags = ["a": PoetryTags(imagery: ["月"], topics: ["思乡"], emotions: ["思念"]), "b": PoetryTags(imagery: ["风"], topics: ["怀人"], emotions: ["思念"]), "c": PoetryTags(imagery: ["月"], topics: ["山水"], emotions: ["宁静"])]
        var state = ExplorationState(selections: [.poet: ["李白", "杜甫"], .emotion: ["思念"]])
        XCTAssertEqual(try app.explore(state, tags: tags).map(\.id), ["a", "b"])
        state.selections[.imagery] = ["月"]
        XCTAssertEqual(try app.explore(state, tags: tags).map(\.id), ["a"])
        state.selections[.topic] = ["山水"]
        XCTAssertTrue(try app.explore(state, tags: tags).isEmpty)
        XCTAssertEqual(state.selections[.poet], ["李白", "杜甫"])
        state.toggle("山水", in: .topic)
        XCTAssertEqual(try app.explore(state, tags: tags).map(\.id), ["a"])
        state.clear()
        // No poem has a known place: place metadata must never gate ordinary search.
        XCTAssertEqual(try app.explore(state, tags: tags), poems)
        for keyword in ["月夜", "举头", "李白"] {
            XCTAssertEqual(try app.explore(ExplorationState(keyword: keyword), tags: tags).map(\.id), ["a"])
        }
    }

    func testOpeningReaderAndRestartRestoreQueryConditionsAndListAnchor() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("search.sqlite")
        let poem = Poem(id: "unknown-place", title: "无地名作品", poetID: "li", poet: "李白", lines: ["明月"], sources: [])
        var app: PoetryApplication? = try PoetryApplication(databaseURL: url, seed: [poem])
        let state = ExplorationState(keyword: "明月", selections: [.dynasty: ["唐"], .poet: ["李白"]], visiblePoemID: poem.id)
        try app?.saveExploration(state)
        XCTAssertEqual(try app?.readPoem(id: poem.id), poem)
        XCTAssertEqual(try app?.restoreExploration(), state)
        app = nil
        let restarted = try PoetryApplication(databaseURL: url, seed: [])
        let restored = try restarted.restoreExploration()
        XCTAssertEqual(restored, state)
        XCTAssertEqual(try restarted.explore(restored), [poem])
        var empty = state
        empty.keyword = "不存在的诗句"
        try restarted.saveExploration(empty)
        XCTAssertTrue(try restarted.explore(restarted.restoreExploration()).isEmpty)
        XCTAssertEqual(try restarted.restoreExploration().selections, state.selections)
    }
}
