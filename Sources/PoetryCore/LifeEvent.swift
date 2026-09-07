import Foundation

public enum LifePoemKind: String, Codable { case associated, contemporary
    public var label: String { self == .associated ? "对应作品" : "同期作品" }
    public var explanation: String { self == .associated ? "资料支持作品与此事件的关联。" : "资料支持创作时间相近，不表示因这件事而作。" }
}
public struct LifePoemLink: Codable, Equatable {
    public var poemID: String
    public var kind: LifePoemKind
    public var sources: [SourceEvidence]
    public init(poemID: String, kind: LifePoemKind, sources: [SourceEvidence]) {
        self.poemID = poemID; self.kind = kind; self.sources = sources
    }
}
public struct LifeEvent: Codable, Equatable, Identifiable {
    public var id: String
    public var poetID: String
    public var title: String
    public var period: String
    /// Relative order supported by sources, not a Gregorian year. Nil means order is unknown.
    public var chronology: Int?
    public var uncertainty: String?
    public var sources: [SourceEvidence]
    public var poemLinks: [LifePoemLink]
    public init(id: String, poetID: String, title: String, period: String, chronology: Int?, uncertainty: String? = nil, sources: [SourceEvidence], poemLinks: [LifePoemLink] = []) {
        self.id = id; self.poetID = poetID; self.title = title; self.period = period
        self.chronology = chronology; self.uncertainty = uncertainty; self.sources = sources; self.poemLinks = poemLinks
    }
}
public struct LifeTimeline: Equatable {
    public let ordered: [LifeEvent]
    public let undated: [LifeEvent]
    public var isEmpty: Bool { ordered.isEmpty && undated.isEmpty }
}
extension PoetryApplication {
    func installLifeEventsIfNeeded() throws {
        try database.execute("CREATE TABLE IF NOT EXISTS life_events (id TEXT PRIMARY KEY, payload TEXT NOT NULL, position INTEGER NOT NULL)")
        guard try database.query("SELECT value FROM app_metadata WHERE key = 'life_events_installed'").isEmpty else { return }
        let events = try Self.bundledLifeEvents()
        try database.transaction {
            for (position, event) in events.enumerated() {
                let payload = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
                try database.execute("INSERT INTO life_events (id, payload, position) VALUES (?, ?, ?)", [.text(event.id), .text(payload), .integer(Int64(position))])
            }
            try database.execute("INSERT INTO app_metadata VALUES ('life_events_installed', '1')")
        }
    }
    public static func bundledLifeEvents() throws -> [LifeEvent] {
        guard let url = Bundle.module.url(forResource: "life-events", withExtension: "json") else { throw DatabaseError(message: "随包生平资料缺失") }
        return try JSONDecoder().decode([LifeEvent].self, from: Data(contentsOf: url))
    }
    public func allLifeEvents() throws -> [LifeEvent] {
        try database.query("SELECT payload FROM life_events ORDER BY position, id").map { row in
            guard let payload = row["payload"]?.string else { throw DatabaseError(message: "生平资料无法读取") }
            return try JSONDecoder().decode(LifeEvent.self, from: Data(payload.utf8))
        }
    }
    public func lifeTimeline(poetID: String) throws -> LifeTimeline {
        let events = try allLifeEvents().filter { $0.poetID == poetID }
        return LifeTimeline(ordered: events.filter { $0.chronology != nil }.sorted { ($0.chronology ?? 0, $0.id) < ($1.chronology ?? 0, $1.id) }, undated: events.filter { $0.chronology == nil })
    }
}
