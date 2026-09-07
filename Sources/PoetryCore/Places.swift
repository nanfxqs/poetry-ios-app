import Foundation

public enum PlaceAssociationKind: String, Codable, CaseIterable, Identifiable {
    case mentioned = "诗中之地", composition = "写作地"
    public var id: String { rawValue }
}
public struct PlaceRegion: Codable, Equatable {
    public let south: Double
    public let north: Double
    public let west: Double
    public let east: Double
}
public struct PoetryPlace: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    /// A broad modern framing region, never a precise historical coordinate.
    public let region: PlaceRegion?
    public let precision: String
    public let caveat: String
    public let geography: SourceEvidence
}
public struct PlaceAssociation: Codable, Equatable {
    public let placeID: String
    public let poemID: String
    public let kind: PlaceAssociationKind
    public let evidence: SourceEvidence
}
public struct PlaceResult: Identifiable {
    public let place: PoetryPlace
    public let poems: [Poem]
    public let associations: [PlaceAssociation]
    public var id: String { place.id }
}

extension PoetryApplication {
    private func preparePlaces() throws {
        try database.execute("CREATE TABLE IF NOT EXISTS places (id TEXT PRIMARY KEY, payload TEXT NOT NULL)")
        try database.execute("CREATE TABLE IF NOT EXISTS place_associations (place_id TEXT NOT NULL, poem_id TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(place_id, poem_id, kind))")
        guard try database.query("SELECT value FROM app_metadata WHERE key = 'places_seed_1'").isEmpty else { return }
        let credit = "仅摘录地理事实，保留来源；不转载文章或图片"
        let places = [
            PoetryPlace(id: "yangzhou", name: "扬州（广陵）", region: PlaceRegion(south: 32.25, north: 33.4166667, west: 119.0166667, east: 119.9), precision: "今地范围示意", caveat: "依据 2014 年资料的现代区域范围。框线仅用于认地方，不是行政边界、唐代广陵边界或写作位置。", geography: SourceEvidence(title: "中国天气网江苏站 · 扬州（2014-11-11）", url: "https://www.weather.com.cn/jiangsu/qxkp/rdzt/11/2224902.shtml", license: credit, note: "原资料经纬度范围换算为十进制度；镜头中心为范围推导值，不作地点钉。")),
            PoetryPlace(id: "huanghelou", name: "黄鹤楼", region: nil, precision: "未核实坐标", caveat: "今楼在武汉蛇山，1985 年重建，距旧址约千米。今址不代表唐代楼址或写作地；暂不标坐标。", geography: SourceEvidence(title: "湖北省委外办 · 黄鹤楼（2022-08-10，来源湖北省政府）", url: "https://www.fohb.gov.cn/info/2022-08/20220810161400_204.html", license: credit, note: "区分旧址与异址重建的今楼，无已核实数字坐标。"))
        ]
        let poemID = "huanghelou-song-meng-haoran"
        try database.transaction {
            for place in places {
                let payload = String(decoding: try JSONEncoder().encode(place), as: UTF8.self)
                try database.execute("INSERT OR IGNORE INTO places VALUES (?, ?)", [.text(place.id), .text(payload)])
                if try readPoem(id: poemID) != nil {
                    let edge = PlaceAssociation(placeID: place.id, poemID: poemID, kind: .mentioned, evidence: SourceEvidence(title: "香港教育局 · 黄鹤楼送孟浩然之广陵参考版本", url: "https://cd.edb.gov.hk/chi/resource/ncs/download/js_list/JS_huanghelousongmenghaoran.pdf", license: "古代作品原文；机构参考版本链接", note: place.id == "yangzhou" ? "题名广陵、诗句扬州支持远行方向，不证明写作地。" : "题名与诗句提及黄鹤楼，支持送别场景，不证明执笔位置。"))
                    let edgeJSON = String(decoding: try JSONEncoder().encode(edge), as: UTF8.self)
                    try database.execute("INSERT OR IGNORE INTO place_associations VALUES (?, ?, ?, ?)", [.text(place.id), .text(poemID), .text(edge.kind.rawValue), .text(edgeJSON)])
                }
            }
            try database.execute("INSERT INTO app_metadata VALUES ('places_seed_1', '1')")
        }
    }

    /// The same local query powers both the geographic display and fallback list.
    /// Map tile availability never participates in filtering or reading.
    public func explorePlaces(_ state: ExplorationState, kind: PlaceAssociationKind) throws -> [PlaceResult] {
        try preparePlaces()
        let poems = try explore(state)
        let edges: [PlaceAssociation] = try database.query("SELECT payload FROM place_associations WHERE kind = ?", [.text(kind.rawValue)]).compactMap { row in
            guard let json = row["payload"]?.string else { return nil }
            return try JSONDecoder().decode(PlaceAssociation.self, from: Data(json.utf8))
        }
        return try database.query("SELECT payload FROM places ORDER BY id").compactMap { row in
            guard let json = row["payload"]?.string else { return nil }
            let place = try JSONDecoder().decode(PoetryPlace.self, from: Data(json.utf8))
            let matches = edges.filter { edge in edge.placeID == place.id && poems.contains(where: { $0.id == edge.poemID }) }
            let matchingPoems = poems.filter { poem in edges.contains { $0.placeID == place.id && $0.poemID == poem.id } }
            guard !matchingPoems.isEmpty else { return nil }
            return PlaceResult(place: place, poems: matchingPoems, associations: matches)
        }
    }
}
