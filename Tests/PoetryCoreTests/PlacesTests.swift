import Foundation
import XCTest
@testable import PoetryCore

final class PlacesTests: XCTestCase {
    func testRegionEvidenceCategoryAndSharedFiltersRemainLocal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("places.sqlite"))
        let places = try app.explorePlaces(ExplorationState(), kind: .mentioned)
        XCTAssertEqual(Set(places.map(\.id)), ["yangzhou", "huanghelou"])
        let yangzhou = try XCTUnwrap(places.first { $0.id == "yangzhou" })
        XCTAssertEqual(yangzhou.place.region?.south, 32.25)
        XCTAssertEqual(yangzhou.place.precision, "今地范围示意")
        XCTAssertTrue(yangzhou.place.caveat.contains("不是行政边界"))
        XCTAssertTrue(places.first { $0.id == "huanghelou" }?.place.region == nil)
        XCTAssertTrue(places.allSatisfy { !$0.place.geography.url.isEmpty && !$0.associations.isEmpty })
        XCTAssertTrue(try app.explorePlaces(ExplorationState(), kind: .composition).isEmpty)
        XCTAssertTrue(try app.explorePlaces(ExplorationState(selections: [.poet: ["王维"]]), kind: .mentioned).isEmpty)
        let query = ExplorationState(keyword: "烟花", selections: [.dynasty: ["唐"]])
        XCTAssertEqual(try app.explorePlaces(query, kind: .mentioned).first?.poems, try app.explore(query))
        XCTAssertNotNil(try app.readPoem(id: "guo-guren-zhuang"))
        // Reopening local SQLite needs neither MapKit nor a tile/network provider.
        let reopened = try PoetryApplication(databaseURL: directory.appendingPathComponent("places.sqlite"))
        XCTAssertEqual(try reopened.explorePlaces(query, kind: .mentioned).map(\.id), places.map(\.id))
    }

    func testUnlocatedPoemsAreReadableWithoutInventedAssociations() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let poem = Poem(id: "unknown", title: "无坐标", poetID: "li", poet: "李白", lines: ["山水"], sources: [])
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("places.sqlite"), seed: [poem])
        XCTAssertTrue(try app.explorePlaces(ExplorationState(), kind: .mentioned).isEmpty)
        XCTAssertEqual(try app.explore(ExplorationState()), [poem])
        XCTAssertEqual(try app.readPoem(id: poem.id), poem)
    }
}
