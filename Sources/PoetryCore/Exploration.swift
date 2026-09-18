import Foundation

public enum ExplorationGroup: String, Codable, CaseIterable, Identifiable {
    case dynasty = "朝代", poet = "诗人", imagery = "意象", emotion = "情绪", topic = "题材"
    public var id: String { rawValue }
}

/// Serializable reading context; navigation does not reset the query or visible poem.
public struct ExplorationState: Codable, Equatable {
    public var keyword: String
    public var selections: [ExplorationGroup: Set<String>]
    public var visiblePoemID: String?
    public init(keyword: String = "", selections: [ExplorationGroup: Set<String>] = [:], visiblePoemID: String? = nil) {
        self.keyword = keyword; self.selections = selections; self.visiblePoemID = visiblePoemID
    }
    public mutating func toggle(_ value: String, in group: ExplorationGroup) {
        if selections[group, default: []].contains(value) { selections[group]?.remove(value) }
        else { selections[group, default: []].insert(value) }
        visiblePoemID = nil
    }
    public mutating func clear() { self = ExplorationState() }
}

extension PoetryApplication {
    public func explore(_ state: ExplorationState, tags: [String: PoetryTags]? = nil) throws -> [Poem] {
        let tags = try tags ?? contentTags()
        let keyword = state.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return try allPoems().filter { poem in
            let textMatches = keyword.isEmpty || ([poem.title, poem.poet] + poem.lines).contains { $0.localizedStandardContains(keyword) }
            return textMatches && ExplorationGroup.allCases.allSatisfy { group in
                let selected = state.selections[group, default: []]
                return selected.isEmpty || !selected.isDisjoint(with: explorationValues(group, poem: poem, tags: tags))
            }
        }
    }
    public func explorationOptions(tags: [String: PoetryTags]? = nil) throws -> [ExplorationGroup: [String]] {
        let tags = try tags ?? contentTags()
        let poems = try allPoems()
        return Dictionary(uniqueKeysWithValues: ExplorationGroup.allCases.map { group in
            (group, Set(poems.flatMap { explorationValues(group, poem: $0, tags: tags) }).sorted())
        })
    }
    public func saveExploration(_ state: ExplorationState) throws {
        let json = String(decoding: try JSONEncoder().encode(state), as: UTF8.self)
        try database.execute("INSERT OR REPLACE INTO app_metadata (key, value) VALUES ('exploration_state', ?)", [.text(json)])
    }
    public func restoreExploration() throws -> ExplorationState {
        guard let json = try database.query("SELECT value FROM app_metadata WHERE key = 'exploration_state'").first?["value"]?.string else { return ExplorationState() }
        return try JSONDecoder().decode(ExplorationState.self, from: Data(json.utf8))
    }
    private func explorationValues(_ group: ExplorationGroup, poem: Poem, tags: [String: PoetryTags]) -> Set<String> {
        switch group {
        case .dynasty: return [poem.dynasty]
        case .poet: return [poem.poet]
        case .imagery: return tags[poem.id]?.imagery ?? []
        case .emotion: return tags[poem.id]?.emotions ?? []
        case .topic: return tags[poem.id]?.topics ?? []
        }
    }
}
