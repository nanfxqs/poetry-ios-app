import Foundation

public struct PoetryTags: Codable, Equatable {
    public var imagery: Set<String>
    public var topics: Set<String>
    public var emotions: Set<String>
    public init(imagery: Set<String> = [], topics: Set<String> = [], emotions: Set<String> = []) {
        self.imagery = imagery; self.topics = topics; self.emotions = emotions
    }
    /// Editorial reading labels inferred from the poems, not historical claims.
    public static let bundled: [String: PoetryTags] = [
        "huanghelou-song-meng-haoran": .init(imagery: ["江水", "帆"], topics: ["送别", "友情"], emotions: ["惜别"]),
        "zeng-meng-haoran": .init(imagery: ["月", "云", "酒"], topics: ["赠友", "友情"], emotions: ["敬慕"]),
        "chunri-yi-li-bai": .init(imagery: ["云", "酒", "树"], topics: ["怀人", "友情"], emotions: ["思念"]),
        "song-yuan-er": .init(imagery: ["雨", "柳", "酒"], topics: ["送别", "友情"], emotions: ["惜别"]),
        "liubie-wang-wei": .init(imagery: ["芳草"], topics: ["送别", "友情"], emotions: ["惜别"]),
        "guo-guren-zhuang": .init(imagery: ["树", "山", "酒", "菊"], topics: ["田园", "友情"], emotions: ["喜悦"])
    ]
}

public struct RelatedPoem: Identifiable, Equatable {
    public let poem: Poem
    public let reason: String
    public var id: String { poem.id }
}

private struct DailySelection: Codable {
    let poem: Poem
    let index: Int
    let selectedAt: Date
    let timezone: String
    let nextDay: Date
}

extension PoetryApplication {
    /// A saved day's boundary is fixed in the timezone in which it was selected.
    /// A timezone change cannot advance it early. After that boundary, subsequent
    /// days use the current local timezone. The snapshot also survives content replacement.
    public func dailyPoem(at date: Date = Date(), timeZone: TimeZone = .current) throws -> Poem? {
        try database.transaction {
            let saved = try database.query("SELECT value FROM app_metadata WHERE key = 'daily_selection'").first?["value"]?.string
            let previous = try saved.map { try JSONDecoder().decode(DailySelection.self, from: Data($0.utf8)) }
            if let previous, date < previous.nextDay { return previous.poem }
            let poems = try allPoems()
            guard !poems.isEmpty else { return previous?.poem }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let index: Int
            if let previous {
                var previousCalendar = calendar
                previousCalendar.timeZone = TimeZone(identifier: previous.timezone) ?? timeZone
                let days = previousCalendar.dateComponents([.day], from: previousCalendar.startOfDay(for: previous.selectedAt), to: previousCalendar.startOfDay(for: date)).day ?? 1
                index = (previous.index + max(1, days)) % poems.count
            } else { index = 0 }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
                throw DatabaseError(message: "无法确定下一阅读日")
            }
            let selection = DailySelection(poem: poems[index], index: index, selectedAt: date, timezone: timeZone.identifier, nextDay: nextDay)
            let payload = String(decoding: try JSONEncoder().encode(selection), as: UTF8.self)
            try database.execute("INSERT INTO app_metadata (key, value) VALUES ('daily_selection', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(payload)])
            return selection.poem
        }
    }

    public func relatedPoems(to poem: Poem, tags: [String: PoetryTags]? = nil) throws -> [RelatedPoem] {
        let tags = try tags ?? contentTags()
        guard let origin = tags[poem.id] else { return [] }
        return try allPoems().filter { $0.id != poem.id }.compactMap { candidate -> RelatedPoem? in
            guard let labels = tags[candidate.id] else { return nil }
            let imagery = origin.imagery.intersection(labels.imagery).sorted()
            let topics = origin.topics.intersection(labels.topics).sorted()
            let reasons = [imagery.isEmpty ? nil : "共同意象：" + imagery.joined(separator: "、"),
                           topics.isEmpty ? nil : "共同题材：" + topics.joined(separator: "、")].compactMap { $0 }
            guard !reasons.isEmpty else { return nil }
            return RelatedPoem(poem: candidate, reason: reasons.joined(separator: "；"))
        }.prefix(3).map { $0 }
    }
}
