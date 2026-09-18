import Foundation
import XCTest
@testable import PoetryCore

final class LifeEventTests: XCTestCase {
    func testSourcedTimelinePersistsWithoutInventingPoemAssociations() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("life.sqlite")
        var app: PoetryApplication? = try PoetryApplication(databaseURL: url)
        let events = try XCTUnwrap(app).allLifeEvents()
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.allSatisfy { !$0.sources.isEmpty && $0.poemLinks.isEmpty })
        XCTAssertTrue(events.flatMap(\.sources).allSatisfy { !$0.note.isEmpty && $0.url.contains("oldid=") })
        let wang = try XCTUnwrap(app).lifeTimeline(poetID: "wang-wei")
        XCTAssertEqual(wang.undated.map(\.id), ["wang-wei-wangchuan"])
        XCTAssertFalse(wang.ordered.contains { $0.id == "wang-wei-wangchuan" })
        XCTAssertTrue(try XCTUnwrap(app).lifeTimeline(poetID: "missing").isEmpty)
        app = nil
        XCTAssertEqual(try PoetryApplication(databaseURL: url).allLifeEvents(), events)
    }

    func testSortAndContemporaryEvidenceSurviveDatabaseAndReadingRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("life.sqlite"))
        let poem = try XCTUnwrap(app.allPoems().first)
        let evidence = SourceEvidence(title: "测试时间依据", url: "https://example.org/evidence", license: "测试夹具", note: "仅证明创作时间相近；不是史实种子。")
        let link = LifePoemLink(poemID: poem.id, kind: .contemporary, sources: [evidence])
        let events = [
            LifeEvent(id: "late", poetID: "fixture", title: "后", period: "约年范围", chronology: 20, sources: [evidence], poemLinks: [link]),
            LifeEvent(id: "unknown", poetID: "fixture", title: "未定", period: "未定", chronology: nil, sources: [evidence]),
            LifeEvent(id: "early", poetID: "fixture", title: "前", period: "早期", chronology: 10, sources: [evidence])
        ]
        for (position, event) in events.enumerated() {
            let payload = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
            try app.database.execute("INSERT INTO life_events (id,payload,position) VALUES (?,?,?)", [.text(event.id), .text(payload), .integer(Int64(position))])
        }
        let before = try app.lifeTimeline(poetID: "fixture")
        XCTAssertEqual(before.ordered.map(\.id), ["early", "late"])
        XCTAssertEqual(before.undated.map(\.id), ["unknown"])
        let savedLink = try XCTUnwrap(before.ordered.last?.poemLinks.first)
        XCTAssertEqual(savedLink.kind.label, "同期作品")
        XCTAssertNotEqual(savedLink.kind.label, LifePoemKind.associated.label)
        XCTAssertTrue(savedLink.kind.explanation.contains("不表示"))
        XCTAssertEqual(savedLink.sources, [evidence])
        XCTAssertEqual(try app.readPoem(id: savedLink.poemID), poem)
        XCTAssertEqual(try app.lifeTimeline(poetID: "fixture"), before)
        XCTAssertTrue(before.ordered[0].poemLinks.isEmpty)
    }
}
