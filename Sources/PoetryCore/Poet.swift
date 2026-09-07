import Foundation

public struct Poet: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var dynasty: String
    public var biography: String?
    public var sources: [SourceEvidence]

    public init(id: String, name: String, dynasty: String = "唐", biography: String?, sources: [SourceEvidence]) {
        self.id = id; self.name = name; self.dynasty = dynasty
        self.biography = biography; self.sources = sources
    }
}

public struct PoetOverview: Equatable {
    public let poet: Poet?
    public let works: [Poem]
    public var biographyUnavailable: Bool {
        poet?.biography?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}

extension PoetryApplication {
    func installPoetsIfNeeded() throws {
        try database.execute("CREATE TABLE IF NOT EXISTS poets (id TEXT PRIMARY KEY, payload TEXT NOT NULL, position INTEGER NOT NULL)")
        guard try database.query("SELECT value FROM app_metadata WHERE key = 'poets_installed'").isEmpty else { return }
        let poets = try Self.bundledPoets()
        try database.transaction {
            for (position, poet) in poets.enumerated() {
                let payload = String(decoding: try JSONEncoder().encode(poet), as: UTF8.self)
                try database.execute("INSERT INTO poets (id, payload, position) VALUES (?, ?, ?)", [.text(poet.id), .text(payload), .integer(Int64(position))])
            }
            try database.execute("INSERT INTO app_metadata VALUES ('poets_installed', '1')")
        }
    }

    public static func bundledPoets() throws -> [Poet] {
        guard let url = Bundle.module.url(forResource: "poets", withExtension: "json") else { throw DatabaseError(message: "随包诗人资料缺失") }
        return try JSONDecoder().decode([Poet].self, from: Data(contentsOf: url))
    }

    public func allPoets() throws -> [Poet] {
        try database.query("SELECT payload FROM poets ORDER BY position, id").map { row in
            guard let payload = row["payload"]?.string else { throw DatabaseError(message: "诗人资料无法读取") }
            return try JSONDecoder().decode(Poet.self, from: Data(payload.utf8))
        }
    }

    /// Works are resolved from the installed corpus by stable author identity, never by display name.
    public func poetOverview(id: String) throws -> PoetOverview {
        PoetOverview(poet: try allPoets().first { $0.id == id }, works: try allPoems().filter { $0.poetID == id })
    }
}
