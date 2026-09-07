import Foundation
import XCTest
@testable import PoetryCore

final class RelationshipTests: XCTestCase {
    func testExactSourcedNeighborhoodPersistsAndEvidenceResolves() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("relationships.sqlite")
        let app = try PoetryApplication(databaseURL: url)
        let graph = try app.relationshipNeighborhood(poetID: "li-bai")
        XCTAssertEqual(graph.relationships.map(\.id), ["du-fu-li-bai", "li-bai-meng-haoran"])
        XCTAssertEqual(Set(graph.people.map(\.id)), ["du-fu", "li-bai", "meng-haoran"])
        XCTAssertEqual(graph.relationships[0].evidencePoemIDs, ["chunri-yi-li-bai"])
        XCTAssertEqual(graph.relationships[1].evidencePoemIDs, ["zeng-meng-haoran", "huanghelou-song-meng-haoran"])
        for relation in try app.allRelationships() {
            XCTAssertFalse(relation.sources.isEmpty)
            for id in relation.evidencePoemIDs { XCTAssertEqual(try app.readPoem(id: id)?.poetID, relation.fromPoetID) }
        }
        XCTAssertEqual(try PoetryApplication(databaseURL: url, seed: []).relationshipNeighborhood(poetID: "li-bai"), graph)
    }

    func testMissingPeopleOrEvidenceDoesNotInventRelationships() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let poems = try PoetryApplication.bundledPoems().filter { $0.id == "guo-guren-zhuang" }
        let app = try PoetryApplication(databaseURL: directory.appendingPathComponent("empty.sqlite"), seed: poems)
        let graph = try app.relationshipNeighborhood(poetID: "meng-haoran")
        XCTAssertTrue(graph.relationships.isEmpty)
        XCTAssertEqual(graph.works.map(\.id), ["guo-guren-zhuang"])
        XCTAssertNil(try app.relationshipNeighborhood(poetID: "unknown").center)
        XCTAssertTrue(try app.relationshipNeighborhood(poetID: "unknown").relationships.isEmpty)
    }
}
