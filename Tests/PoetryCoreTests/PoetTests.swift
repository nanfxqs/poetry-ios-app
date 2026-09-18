import Foundation
import XCTest
@testable import PoetryCore

final class PoetTests: XCTestCase {
    func testFourSourcedPoetsAndTheirWorksRemainAvailableOfflineAfterRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("poets.sqlite")
        var app: PoetryApplication? = try PoetryApplication(databaseURL: url)
        let poets = try XCTUnwrap(app).allPoets()
        XCTAssertEqual(Set(poets.map(\.id)), ["li-bai", "du-fu", "wang-wei", "meng-haoran"])
        for poet in poets {
            let overview = try XCTUnwrap(app).poetOverview(id: poet.id)
            XCTAssertFalse(overview.biographyUnavailable)
            XCTAssertFalse(overview.works.isEmpty)
            XCTAssertTrue(overview.works.allSatisfy { $0.poetID == poet.id })
            XCTAssertFalse(poet.sources.isEmpty)
            XCTAssertTrue(poet.sources.allSatisfy { !$0.note.isEmpty && !$0.license.isEmpty && $0.url.contains("oldid=") })
        }
        app = nil
        XCTAssertEqual(try PoetryApplication(databaseURL: url, seed: []).allPoets(), poets)
    }

    func testAuthorIdentityDoesNotUseDisplayNameAndMissingBiographyDoesNotHideWorks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let poem = Poem(id: "unknown-work", title: "同名作者作品", poetID: "another-li-bai", poet: "李白", lines: ["正文"], sources: [])
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("poets.sqlite"), seed: [poem])
        XCTAssertTrue(try app.poetOverview(id: "li-bai").works.isEmpty)
        let missing = try app.poetOverview(id: "another-li-bai")
        XCTAssertNil(missing.poet)
        XCTAssertTrue(missing.biographyUnavailable)
        XCTAssertEqual(missing.works, [poem])
        XCTAssertTrue(try app.poetOverview(id: "absent").works.isEmpty)
    }
}
