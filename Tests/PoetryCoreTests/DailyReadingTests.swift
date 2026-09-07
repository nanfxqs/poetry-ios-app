import Foundation
import XCTest
@testable import PoetryCore

final class DailyReadingTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private let utc = TimeZone(secondsFromGMT: 0)!

    func testSameDayRestartNextDaySkippedDaysAndCycle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("daily.sqlite")
        var app: PoetryApplication? = try PoetryApplication(databaseURL: url)
        let poems = try XCTUnwrap(app).allPoems()
        XCTAssertEqual(try app?.dailyPoem(at: date("2026-09-01T10:00:00Z"), timeZone: utc), poems[0])
        app = nil
        let reopened = try PoetryApplication(databaseURL: url)
        XCTAssertEqual(try reopened.dailyPoem(at: date("2026-09-01T23:59:59Z"), timeZone: utc), poems[0])
        XCTAssertEqual(try reopened.dailyPoem(at: date("2026-09-02T00:00:00Z"), timeZone: utc), poems[1])
        XCTAssertEqual(try reopened.dailyPoem(at: date("2026-09-07T10:00:00Z"), timeZone: utc), poems[0])
    }

    func testTimezoneChangeDoesNotReplaceSelectedDayEarly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("daily.sqlite")
        let app = try PoetryApplication(databaseURL: url)
        let first = try app.dailyPoem(at: date("2026-09-01T20:00:00Z"), timeZone: utc)
        let east = TimeZone(secondsFromGMT: 9 * 3600)!
        let restarted = try PoetryApplication(databaseURL: url)
        XCTAssertEqual(try restarted.dailyPoem(at: date("2026-09-01T21:00:00Z"), timeZone: east), first)
        let second = try restarted.dailyPoem(at: date("2026-09-02T00:00:00Z"), timeZone: east)
        XCTAssertNotEqual(second, first)
        XCTAssertEqual(try restarted.dailyPoem(at: date("2026-09-02T14:59:59Z"), timeZone: east), second)
        XCTAssertNotEqual(try restarted.dailyPoem(at: date("2026-09-02T15:00:00Z"), timeZone: east), second)
    }

    func testRelatedPoemsExcludeSelfHaveReasonsLimitThreeAndOmitUnknownTags() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("daily.sqlite"))
        let poem = try XCTUnwrap(app.allPoems().first)
        let related = try app.relatedPoems(to: poem)
        XCTAssertEqual(related.count, 3)
        XCTAssertTrue(related.allSatisfy { $0.id != poem.id && $0.reason.contains("共同题材：") })
        XCTAssertTrue(try app.relatedPoems(to: poem, tags: [:]).isEmpty)
        let candidate = try app.allPoems()[1]
        let imageryOnly = try app.relatedPoems(to: poem, tags: [poem.id: .init(imagery: ["月"]), candidate.id: .init(imagery: ["月"])])
        XCTAssertEqual(imageryOnly.map(\.id), [candidate.id])
        XCTAssertEqual(imageryOnly.first?.reason, "共同意象：月")
        XCTAssertTrue(try app.relatedPoems(to: poem, tags: [poem.id: .init(topics: ["独有"]), candidate.id: .init(topics: ["其他"])]).isEmpty)
    }
}
