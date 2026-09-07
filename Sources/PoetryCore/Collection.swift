import Foundation

public struct FavoritePoem: Identifiable, Equatable, Codable {
    public var id: String { poem.id }
    public let poem: Poem
    public let savedAt: Date
}

extension PoetryApplication {
    func prepareCollection() throws {
        // A snapshot deliberately has no foreign key to replaceable content.
        try database.execute("CREATE TABLE IF NOT EXISTS favorites (sequence INTEGER PRIMARY KEY AUTOINCREMENT, poem_id TEXT NOT NULL UNIQUE, payload TEXT NOT NULL, saved_at REAL NOT NULL)")
    }

    public func isFavorite(id: String) throws -> Bool {
        try prepareCollection()
        return try !database.query("SELECT poem_id FROM favorites WHERE poem_id = ?", [.text(id)]).isEmpty
    }

    /// Repeated saves retain the original position and snapshot.
    public func saveFavorite(_ poem: Poem, at date: Date = Date()) throws {
        try prepareCollection()
        let payload = String(decoding: try JSONEncoder().encode(poem), as: UTF8.self)
        try prepareBackup()
        try database.transaction {
            guard try !isFavorite(id: poem.id) else { return }
            try database.execute("INSERT INTO favorites (poem_id, payload, saved_at) VALUES (?, ?, ?)", [.text(poem.id), .text(payload), .real(date.timeIntervalSince1970)])
            try advanceCollectionRevision()
        }
    }

    public func removeFavorite(id: String) throws {
        try prepareCollection()
        try prepareBackup()
        try database.transaction {
            guard try isFavorite(id: id) else { return }
            try database.execute("DELETE FROM favorites WHERE poem_id = ?", [.text(id)])
            try advanceCollectionRevision()
        }
    }

    public func favoritePoems(search: String = "") throws -> [FavoritePoem] {
        try prepareCollection()
        let favorites = try database.query("SELECT payload, saved_at FROM favorites ORDER BY sequence DESC").map { row -> FavoritePoem in
            guard let payload = row["payload"]?.string, case .real(let time) = row["saved_at"] else {
                throw DatabaseError(message: "收藏数据无法读取")
            }
            return FavoritePoem(poem: try JSONDecoder().decode(Poem.self, from: Data(payload.utf8)), savedAt: Date(timeIntervalSince1970: time))
        }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return favorites }
        return favorites.filter { favorite in
            ([favorite.poem.title, favorite.poem.poet] + favorite.poem.lines).contains { $0.localizedStandardContains(query) }
        }
    }
}
