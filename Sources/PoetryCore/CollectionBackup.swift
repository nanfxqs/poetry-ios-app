import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct CollectionSnapshot: Codable, Equatable {
    public let deviceID: String
    public let revision: Int64
    /// Newest first, including complete offline poem snapshots.
    public let favorites: [FavoritePoem]
}
public struct CollectionBackupReceipt: Codable, Equatable {
    public let snapshot: CollectionSnapshot
    public let receivedAt: Double
}
public struct CollectionBackupStatus {
    public let pending: Bool
    public let lastSuccess: Date?
}

extension PoetryApplication {
    func prepareBackup() throws {
        try prepareCollection()
        try database.execute("CREATE TABLE IF NOT EXISTS collection_backup (singleton INTEGER PRIMARY KEY CHECK(singleton=1), device TEXT NOT NULL, revision INTEGER NOT NULL, acknowledged INTEGER NOT NULL, success REAL)")
        try database.execute("INSERT OR IGNORE INTO collection_backup VALUES (1, ?, CASE WHEN EXISTS(SELECT 1 FROM favorites) THEN 1 ELSE 0 END, 0, NULL)", [.text(UUID().uuidString.lowercased())])
    }
    func advanceCollectionRevision() throws {
        try database.execute("UPDATE collection_backup SET revision = revision + 1 WHERE singleton=1")
    }
    public func collectionSnapshot() throws -> CollectionSnapshot {
        try prepareBackup()
        let row = try database.query("SELECT * FROM collection_backup")[0]
        return CollectionSnapshot(deviceID: row["device"]!.string!, revision: row["revision"]!.integer!, favorites: try favoritePoems())
    }
    public func collectionBackupStatus() throws -> CollectionBackupStatus {
        try prepareBackup()
        let row = try database.query("SELECT * FROM collection_backup")[0]
        let time: Date?
        if case .real(let value) = row["success"] { time = Date(timeIntervalSince1970: value) } else { time = nil }
        return CollectionBackupStatus(pending: row["revision"]!.integer! > row["acknowledged"]!.integer!, lastSuccess: time)
    }
    public func acknowledgeCollectionBackup(_ receipt: CollectionBackupReceipt, sent: CollectionSnapshot) throws {
        guard receipt.snapshot == sent, receipt.receivedAt.isFinite else { throw ContentUpdateError.invalid }
        try prepareBackup()
        try database.execute("UPDATE collection_backup SET acknowledged=MAX(acknowledged, ?), success=? WHERE device=? AND revision>=?", [.integer(sent.revision), .real(receipt.receivedAt), .text(sent.deviceID), .integer(sent.revision)])
    }
    /// Explicit user operation. The canonical service identity survives reinstall through this receipt.
    public func restoreCollection(_ receipt: CollectionBackupReceipt) throws {
        let snapshot = receipt.snapshot
        guard UUID(uuidString: snapshot.deviceID) != nil, snapshot.revision > 0, receipt.receivedAt.isFinite,
              Set(snapshot.favorites.map(\.id)).count == snapshot.favorites.count,
              snapshot.favorites.allSatisfy({ !$0.id.isEmpty && !$0.poem.title.isEmpty && !$0.poem.lines.isEmpty && $0.savedAt.timeIntervalSince1970.isFinite }) else { throw ContentUpdateError.invalid }
        _ = try favoritePoems()
        try prepareBackup()
        try database.transaction {
            try database.execute("DELETE FROM favorites")
            for item in snapshot.favorites.reversed() {
                let payload = String(decoding: try JSONEncoder().encode(item.poem), as: UTF8.self)
                try database.execute("INSERT INTO favorites (poem_id,payload,saved_at) VALUES (?,?,?)", [.text(item.id), .text(payload), .real(item.savedAt.timeIntervalSince1970)])
            }
            try database.execute("UPDATE collection_backup SET device=?,revision=?,acknowledged=?,success=?", [.text(snapshot.deviceID), .integer(snapshot.revision), .integer(snapshot.revision), .real(receipt.receivedAt)])
        }
    }
}

public final class CollectionBackupClient {
    private let credentials: ServiceCredentials
    private let session: URLSession
    public init(credentials: ServiceCredentials, session: URLSession? = nil) {
        self.credentials = credentials
        self.session = session ?? URLSession(configuration: .ephemeral, delegate: BackupRedirectGuard(), delegateQueue: nil)
    }
    public func fetch() async throws -> CollectionBackupReceipt { try await request(snapshot: nil) }
    public func upload(_ snapshot: CollectionSnapshot) async throws -> CollectionBackupReceipt { try await request(snapshot: snapshot) }
    private func request(snapshot: CollectionSnapshot?) async throws -> CollectionBackupReceipt {
        var request = URLRequest(url: credentials.baseURL.appendingPathComponent("v1/backup"))
        request.setValue("Bearer " + credentials.token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        if let snapshot {
            request.httpMethod = "PUT"
            request.httpBody = try JSONEncoder().encode(snapshot)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count <= 8_000_000 else { throw ContentUpdateError.unavailable }
        return try JSONDecoder().decode(CollectionBackupReceipt.self, from: data)
    }
}

private final class BackupRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
