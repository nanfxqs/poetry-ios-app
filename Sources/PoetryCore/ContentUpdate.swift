import Foundation
import CryptoKit

public struct ContentPackage: Codable {
    public let schemaVersion: Int
    public let version: Int
    /// SHA256 covers the exact UTF-8 bytes of payload, not reserialized JSON.
    public let sha256: String
    public let payload: String
    public init(schemaVersion: Int = 1, version: Int, sha256: String, payload: String) {
        self.schemaVersion = schemaVersion; self.version = version; self.sha256 = sha256; self.payload = payload
    }
}

public enum ContentUpdateError: Error, LocalizedError {
    case invalid, outdated, unavailable
    public var errorDescription: String? {
        switch self {
        case .invalid: return "内容包未通过校验，已保留原有内容。"
        case .outdated: return "当前已是此版本或更新版本。"
        case .unavailable: return "暂时无法连接个人服务，原有内容仍可阅读。"
        }
    }
}

extension PoetryApplication {
    public func contentVersion() throws -> Int {
        Int(try database.query("SELECT value FROM app_metadata WHERE key = 'content_version'").first?["value"]?.string ?? "0") ?? 0
    }

    /// Unknown catalogs are rejected, never silently discarded. All content and the
    /// version change in one transaction; personal records and daily snapshots are untouched.
    public func installContentPackage(data: Data) throws {
        guard data.count <= 8_000_000 else { throw ContentUpdateError.invalid }
        let package = try JSONDecoder().decode(ContentPackage.self, from: data)
        let payload = Data(package.payload.utf8)
        let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        guard package.schemaVersion == 1, package.version > 0, digest == package.sha256,
              let root = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
              Set(root.keys) == Set(["poems", "catalogs"]),
              let poemObjects = root["poems"], let catalogs = root["catalogs"] as? [String: Any],
              Set(catalogs.keys) == Set(["poets", "places", "placeAssociations", "tags", "lifeEvents", "relationships"]) else { throw ContentUpdateError.invalid }
        let poems = try JSONDecoder().decode([Poem].self, from: JSONSerialization.data(withJSONObject: poemObjects))
        guard !poems.isEmpty, Set(poems.map(\.id)).count == poems.count else { throw ContentUpdateError.invalid }
        for poem in poems {
            guard Self.validContentID(poem.id), Self.validContentID(poem.poetID), !poem.title.isEmpty,
                  !poem.poet.isEmpty, !poem.lines.isEmpty, poem.lines.allSatisfy({ !$0.isEmpty }),
                  !poem.sources.isEmpty, poem.sources.allSatisfy({ !$0.title.isEmpty && !$0.license.isEmpty && URL(string: $0.url)?.scheme == "https" }) else { throw ContentUpdateError.invalid }
        }
        let catalogData = try ContentCatalogs(catalogs, poemIDs: Set(poems.map(\.id)), authorIDs: Set(poems.map(\.poetID)), poemAuthors: Dictionary(uniqueKeysWithValues: poems.map { ($0.id, $0.poetID) }))
        try database.transaction {
            guard package.version > (try contentVersion()) else { throw ContentUpdateError.outdated }
            try catalogData.install(database)
            try database.execute("DELETE FROM poems")
            for (position, poem) in poems.enumerated() {
                let text = String(decoding: try JSONEncoder().encode(poem), as: UTF8.self)
                try database.execute("INSERT INTO poems VALUES (?, ?, ?)", [.text(poem.id), .text(text), .integer(Int64(position))])
            }
            try database.execute("INSERT INTO app_metadata VALUES ('content_version', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(String(package.version))])
        }
    }
    private static func validContentID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 128 && id.range(of: "^[a-z0-9][a-z0-9._-]*$", options: .regularExpression) != nil
    }
}

public struct ServiceCredentials {
    public let baseURL: URL
    public let token: String
    public init(baseURL: URL, token: String) throws {
        guard baseURL.scheme == "https", baseURL.host != nil, baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil, !token.isEmpty,
              !token.contains("\n"), !token.contains("\r") else { throw ContentUpdateError.invalid }
        self.baseURL = baseURL; self.token = token
    }
}

public final class PoetryServiceClient {
    public let credentials: ServiceCredentials
    private let session: URLSession
    public init(credentials: ServiceCredentials, session: URLSession? = nil) {
        self.credentials = credentials; self.session = session ?? URLSession(configuration: .ephemeral, delegate: ServiceRedirectGuard(), delegateQueue: nil)
    }
    public func downloadContent() async throws -> Data {
        var request = URLRequest(url: credentials.baseURL.appendingPathComponent("v1/content"))
        request.setValue("Bearer " + credentials.token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url?.host == credentials.baseURL.host, data.count <= 8_000_000 else { throw ContentUpdateError.unavailable }
        return data
    }
}

private struct ContentCatalogs {
    let poets: [[String: Any]]
    let places: [[String: Any]]
    let associations: [[String: Any]]
    let tags: [String: Any]
    let lifeEvents: [[String: Any]]
    let relationships: [[String: Any]]
    init(_ raw: [String: Any], poemIDs: Set<String>, authorIDs: Set<String>, poemAuthors: [String: String]) throws {
        guard let poets = raw["poets"] as? [[String: Any]], let places = raw["places"] as? [[String: Any]],
              let associations = raw["placeAssociations"] as? [[String: Any]], let tags = raw["tags"] as? [String: Any], let lifeEvents = raw["lifeEvents"] as? [[String: Any]], let relationships = raw["relationships"] as? [[String: Any]] else { throw ContentUpdateError.invalid }
        func ids(_ rows: [[String: Any]]) throws -> Set<String> {
            let values = rows.compactMap { $0["id"] as? String }
            guard values.count == rows.count, Set(values).count == rows.count,
                  values.allSatisfy({ $0.range(of: "^[a-z0-9][a-z0-9._-]{0,127}$", options: .regularExpression) != nil }) else { throw ContentUpdateError.invalid }
            return Set(values)
        }
        func evidence(_ raw: Any?) -> Bool {
            guard let e = raw as? [String: Any] else { return false }
            guard e["note"] is String else { return false }
            return ["title", "license", "url"].allSatisfy { (e[$0] as? String)?.isEmpty == false } && (e["url"] as? String)?.hasPrefix("https://") == true
        }
        let poetIDs = try ids(poets), placeIDs = try ids(places)
        guard authorIDs.isSubset(of: poetIDs), Set(tags.keys).isSubset(of: poemIDs) else { throw ContentUpdateError.invalid }
        for poet in poets {
            if let biography = poet["biography"], !(biography is NSNull), !(biography is String) { throw ContentUpdateError.invalid }
            guard (poet["name"] as? String)?.isEmpty == false, poet["dynasty"] is String,
                  let sources = poet["sources"] as? [Any], !sources.isEmpty, sources.allSatisfy({ evidence($0) }) else { throw ContentUpdateError.invalid }
        }
        for place in places {
            guard (place["name"] as? String)?.isEmpty == false, place["precision"] is String, place["caveat"] is String, evidence(place["geography"]) else { throw ContentUpdateError.invalid }
            if let region = place["region"], !(region is NSNull) {
                guard let r = region as? [String: Double], let s = r["south"], let n = r["north"], let w = r["west"], let e = r["east"], s >= -90, n <= 90, s <= n, w >= -180, e <= 180, w <= e else { throw ContentUpdateError.invalid }
            }
        }
        var edges = Set<String>()
        for edge in associations {
            guard let p = edge["placeID"] as? String, placeIDs.contains(p), let poem = edge["poemID"] as? String, poemIDs.contains(poem),
                  let kind = edge["kind"] as? String, ["诗中之地", "写作地"].contains(kind), evidence(edge["evidence"]), edges.insert(p + ":" + poem + ":" + kind).inserted else { throw ContentUpdateError.invalid }
        }
        for value in tags.values {
            guard let t = value as? [String: [String]], Set(t.keys) == Set(["imagery", "topics", "emotions"]) else { throw ContentUpdateError.invalid }
        }
        _ = try ids(lifeEvents)
        for event in lifeEvents {
            if let uncertainty = event["uncertainty"], !(uncertainty is NSNull), !(uncertainty is String) { throw ContentUpdateError.invalid }
            guard let author = event["poetID"] as? String, poetIDs.contains(author), (event["title"] as? String)?.isEmpty == false,
                  (event["period"] as? String)?.isEmpty == false, let sources = event["sources"] as? [Any], !sources.isEmpty, sources.allSatisfy({ evidence($0) }),
                  let links = event["poemLinks"] as? [[String: Any]] else { throw ContentUpdateError.invalid }
            if let order = event["chronology"], !(order is NSNull), !(order is Int) { throw ContentUpdateError.invalid }
            for link in links {
                guard let poem = link["poemID"] as? String, poemIDs.contains(poem), let kind = link["kind"] as? String,
                      ["associated", "contemporary"].contains(kind), let proof = link["sources"] as? [Any], !proof.isEmpty, proof.allSatisfy({ evidence($0) }) else { throw ContentUpdateError.invalid }
            }
        }
        _ = try ids(relationships)
        for relation in relationships {
            guard let from = relation["fromPoetID"] as? String, poetIDs.contains(from),
                  let to = relation["toPoetID"] as? String, poetIDs.contains(to), from != to,
                  (relation["kind"] as? String)?.isEmpty == false,
                  (relation["summary"] as? String)?.isEmpty == false,
                  let links = relation["evidencePoemIDs"] as? [String], !links.isEmpty,
                  Set(links).count == links.count, links.allSatisfy({ poemAuthors[$0] == from }),
                  let sources = relation["sources"] as? [Any], !sources.isEmpty,
                  sources.allSatisfy({ evidence($0) }) else { throw ContentUpdateError.invalid }
        }
        self.relationships = relationships
        self.lifeEvents = lifeEvents
        self.poets = poets; self.places = places; self.associations = associations; self.tags = tags
    }
    func install(_ db: SQLiteDatabase) throws {
        func json(_ value: Any) throws -> String { String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self) }
        try db.execute("CREATE TABLE IF NOT EXISTS poets (id TEXT PRIMARY KEY, payload TEXT NOT NULL, position INTEGER NOT NULL)")
        try db.execute("CREATE TABLE IF NOT EXISTS places (id TEXT PRIMARY KEY, payload TEXT NOT NULL)")
        try db.execute("CREATE TABLE IF NOT EXISTS place_associations (place_id TEXT NOT NULL, poem_id TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(place_id, poem_id, kind))")
        try db.execute("CREATE TABLE IF NOT EXISTS life_events (id TEXT PRIMARY KEY, payload TEXT NOT NULL, position INTEGER NOT NULL)")
        try db.execute("CREATE TABLE IF NOT EXISTS relationships (id TEXT PRIMARY KEY, payload TEXT NOT NULL, position INTEGER NOT NULL)")
        for table in ["poets", "places", "place_associations", "life_events", "relationships"] { try db.execute("DELETE FROM " + table) }
        for (i, row) in poets.enumerated() { try db.execute("INSERT INTO poets VALUES (?, ?, ?)", [.text(row["id"] as! String), .text(try json(row)), .integer(Int64(i))]) }
        for row in places { try db.execute("INSERT INTO places VALUES (?, ?)", [.text(row["id"] as! String), .text(try json(row))]) }
        for row in associations { try db.execute("INSERT INTO place_associations VALUES (?, ?, ?, ?)", [.text(row["placeID"] as! String), .text(row["poemID"] as! String), .text(row["kind"] as! String), .text(try json(row))]) }
        for (i, row) in lifeEvents.enumerated() { try db.execute("INSERT INTO life_events VALUES (?, ?, ?)", [.text(row["id"] as! String), .text(try json(row)), .integer(Int64(i))]) }
        for (i, row) in relationships.enumerated() { try db.execute("INSERT INTO relationships VALUES (?, ?, ?)", [.text(row["id"] as! String), .text(try json(row)), .integer(Int64(i))]) }
        for key in ["poets_installed", "places_seed_1", "life_events_installed", "relationships_installed"] { try db.execute("INSERT INTO app_metadata VALUES (?, '1') ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(key)]) }
        try db.execute("INSERT INTO app_metadata VALUES ('content_tags', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(try json(tags))])
    }
}

private final class ServiceRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

extension PoetryApplication {
    public func contentTags() throws -> [String: PoetryTags] {
        guard let json = try database.query("SELECT value FROM app_metadata WHERE key = 'content_tags'").first?["value"]?.string else { return PoetryTags.bundled }
        return try JSONDecoder().decode([String: PoetryTags].self, from: Data(json.utf8))
    }
}
