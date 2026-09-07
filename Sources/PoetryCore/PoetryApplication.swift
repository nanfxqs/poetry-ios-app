import Foundation

public struct SourceEvidence: Codable, Equatable, Hashable {
    public var title: String
    public var url: String
    public var license: String
    public var note: String
    public init(title: String, url: String, license: String, note: String) {
        self.title = title; self.url = url; self.license = license; self.note = note
    }
}

public struct Poem: Codable, Equatable, Identifiable, Hashable {
    public var id: String
    public var title: String
    public var poetID: String
    public var poet: String
    public var dynasty: String
    public var lines: [String]
    public var background: String?
    public var sources: [SourceEvidence]
    public init(id: String, title: String, poetID: String, poet: String, dynasty: String = "唐", lines: [String], background: String? = nil, sources: [SourceEvidence]) {
        self.id = id; self.title = title; self.poetID = poetID; self.poet = poet; self.dynasty = dynasty
        self.lines = lines; self.background = background; self.sources = sources
    }
}

/// Public user-operation boundary, shared by SwiftUI and real SQLite tests.
public final class PoetryApplication {
    public let database: SQLiteDatabase
    public init(databaseURL: URL, seed: [Poem]? = nil) throws {
        database = try SQLiteDatabase(url: databaseURL)
        try database.execute("CREATE TABLE IF NOT EXISTS poems (id TEXT PRIMARY KEY, payload TEXT NOT NULL, position INTEGER NOT NULL)")
        try database.execute("CREATE TABLE IF NOT EXISTS app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        if try database.query("SELECT value FROM app_metadata WHERE key = 'seed_installed'").isEmpty {
            let poems = try seed ?? Self.bundledPoems()
            try database.transaction {
                for (position, poem) in poems.enumerated() {
                    let data = try JSONEncoder().encode(poem)
                    try database.execute("INSERT INTO poems (id, payload, position) VALUES (?, ?, ?)", [.text(poem.id), .text(String(decoding: data, as: UTF8.self)), .integer(Int64(position))])
                }
                try database.execute("INSERT INTO app_metadata VALUES ('seed_installed', '1')")
            }
        }
    }
    public static func bundledPoems() throws -> [Poem] {
        guard let url = Bundle.module.url(forResource: "seed", withExtension: "json") else { throw DatabaseError(message: "随包作品缺失") }
        return try JSONDecoder().decode([Poem].self, from: Data(contentsOf: url))
    }
    public func readPoem(id: String) throws -> Poem? {
        try database.query("SELECT payload FROM poems WHERE id = ?", [.text(id)]).first.map(decode)
    }
    public func allPoems() throws -> [Poem] { try database.query("SELECT payload FROM poems ORDER BY position, id").map(decode) }
    private func decode(_ row: [String: SQLiteValue]) throws -> Poem {
        guard let text = row["payload"]?.string else { throw DatabaseError(message: "作品数据无法读取") }
        return try JSONDecoder().decode(Poem.self, from: Data(text.utf8))
    }
}
