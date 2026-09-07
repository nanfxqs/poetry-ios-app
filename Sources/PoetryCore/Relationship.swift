import Foundation

public struct Relationship: Codable, Equatable, Identifiable {
    public var id: String
    public var fromPoetID: String
    public var toPoetID: String
    public var kind: String
    public var summary: String
    public var evidencePoemIDs: [String]
    public var sources: [SourceEvidence]
}

public struct RelationshipNeighborhood: Equatable {
    public let center: Poet?
    public let people: [Poet]
    public let relationships: [Relationship]
    public let works: [Poem]
}

extension PoetryApplication {
    public static func bundledRelationships() throws -> [Relationship] {
        guard let url = Bundle.module.url(forResource: "relationships", withExtension: "json") else { throw DatabaseError(message: "随包人物关系缺失") }
        return try JSONDecoder().decode([Relationship].self, from: Data(contentsOf: url))
    }

    func installRelationshipsIfNeeded() throws {
        try database.execute("CREATE TABLE IF NOT EXISTS relationships (id TEXT PRIMARY KEY, payload TEXT NOT NULL, position INTEGER NOT NULL)")
        guard try database.query("SELECT value FROM app_metadata WHERE key = 'relationships_installed'").isEmpty else { return }
        try database.transaction {
            for (position, relationship) in try Self.bundledRelationships().enumerated() {
                let payload = String(decoding: try JSONEncoder().encode(relationship), as: UTF8.self)
                try database.execute("INSERT INTO relationships VALUES (?, ?, ?)", [.text(relationship.id), .text(payload), .integer(Int64(position))])
            }
            try database.execute("INSERT INTO app_metadata VALUES ('relationships_installed', '1')")
        }
    }

    public func allRelationships() throws -> [Relationship] {
        try database.query("SELECT payload FROM relationships ORDER BY position, id").map { row in
            guard let payload = row["payload"]?.string else { throw DatabaseError(message: "人物关系无法读取") }
            return try JSONDecoder().decode(Relationship.self, from: Data(payload.utf8))
        }
    }

    /// Missing evidence or people never creates a dangling graph connection.
    public func relationshipNeighborhood(poetID: String) throws -> RelationshipNeighborhood {
        let poets = try allPoets()
        let poems = try allPoems()
        let poetIDs = Set(poets.map(\.id))
        let relationships = try allRelationships().filter { relation in
            (relation.fromPoetID == poetID || relation.toPoetID == poetID) &&
            relation.fromPoetID != relation.toPoetID &&
            poetIDs.contains(relation.fromPoetID) && poetIDs.contains(relation.toPoetID) &&
            !relation.sources.isEmpty && !relation.evidencePoemIDs.isEmpty &&
            relation.evidencePoemIDs.allSatisfy { id in poems.contains { $0.id == id && $0.poetID == relation.fromPoetID } }
        }.sorted { $0.id < $1.id }
        let connectedIDs = Set(relationships.flatMap { [$0.fromPoetID, $0.toPoetID] })
        return RelationshipNeighborhood(center: poets.first { $0.id == poetID },
            people: poets.filter { connectedIDs.contains($0.id) }.sorted { $0.id < $1.id },
            relationships: relationships, works: poems.filter { $0.poetID == poetID })
    }
}
