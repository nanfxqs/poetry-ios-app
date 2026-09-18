import XCTest
@testable import PoetryCore

final class CollectionBackupTests: XCTestCase {
    private func open(_ url: URL) throws -> PoetryApplication { try PoetryApplication(databaseURL: url) }
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("test.sqlite") }
    func testDurableRevisionRetryAndMutationDuringUpload() throws {
        let url = location()
        let app = try open(url)
        XCTAssertFalse(try app.collectionBackupStatus().pending)
        let poems = try app.allPoems()
        try app.saveFavorite(poems[0])
        let sent = try app.collectionSnapshot()
        try app.saveFavorite(poems[0])
        XCTAssertEqual(try app.collectionSnapshot(), sent)
        try app.saveFavorite(poems[1])
        try app.acknowledgeCollectionBackup(.init(snapshot: sent, receivedAt: 123), sent: sent)
        XCTAssertTrue(try app.collectionBackupStatus().pending)
        let reopened = try open(url)
        XCTAssertEqual(try reopened.collectionSnapshot().revision, sent.revision + 1)
        XCTAssertEqual(try reopened.collectionSnapshot().deviceID, sent.deviceID)
        try reopened.removeFavorite(id: poems[0].id)
        let latest = try reopened.collectionSnapshot()
        XCTAssertEqual(latest.favorites.map(\.id), [poems[1].id])
        try reopened.acknowledgeCollectionBackup(.init(snapshot: latest, receivedAt: 124), sent: latest)
        XCTAssertFalse(try reopened.collectionBackupStatus().pending)
    }
    func testExplicitRestoreKeepsOrderAndAdoptsRevisionAndRollsBackFailure() throws {
        let original = try open(location())
        let poems = try original.allPoems()
        try original.saveFavorite(poems[0]); try original.saveFavorite(poems[1])
        let snapshot = try original.collectionSnapshot()
        // Encode and decode the real wire contract, including Swift Date values.
        let receipt = try JSONDecoder().decode(CollectionBackupReceipt.self, from: JSONEncoder().encode(CollectionBackupReceipt(snapshot: snapshot, receivedAt: 100)))
        let url = location()
        let fresh = try open(url)
        XCTAssertFalse(try fresh.collectionBackupStatus().pending)
        try fresh.restoreCollection(receipt)
        XCTAssertEqual(try fresh.favoritePoems(), snapshot.favorites)
        XCTAssertEqual(try open(url).collectionSnapshot(), snapshot)
        try fresh.removeFavorite(id: poems[0].id)
        XCTAssertEqual(try fresh.collectionSnapshot().revision, snapshot.revision + 1)
        let before = try fresh.collectionSnapshot()
        let duplicate = CollectionSnapshot(deviceID: snapshot.deviceID, revision: snapshot.revision, favorites: snapshot.favorites + snapshot.favorites)
        XCTAssertThrowsError(try fresh.restoreCollection(.init(snapshot: duplicate, receivedAt: 100)))
        XCTAssertEqual(try fresh.collectionSnapshot(), before)
        try fresh.database.execute("CREATE TRIGGER reject_restore BEFORE INSERT ON favorites BEGIN SELECT RAISE(ABORT, 'failure'); END")
        XCTAssertThrowsError(try fresh.restoreCollection(receipt))
        XCTAssertEqual(try fresh.collectionSnapshot(), before)
    }
    func testMutationFailureDoesNotAdvanceRevision() throws {
        let app = try open(location())
        let poem = try app.allPoems()[0]
        let before = try app.collectionSnapshot()
        try app.database.execute("CREATE TRIGGER reject_save BEFORE INSERT ON favorites BEGIN SELECT RAISE(ABORT, 'failure'); END")
        XCTAssertThrowsError(try app.saveFavorite(poem))
        XCTAssertEqual(try app.collectionSnapshot(), before)
    }
}
