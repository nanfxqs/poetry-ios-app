import SwiftUI
import PoetryCore
import MapKit

struct ExploreView: View {
    let application: PoetryApplication
    @State private var state = ExplorationState()
    @State private var poems: [Poem] = []
    @State private var options: [ExplorationGroup: [String]] = [:]
    @State private var expanded = Set<ExplorationGroup>()
    @State private var failure: String?
    @State private var loaded = false
    @State private var places: [PlaceResult] = []
    @State private var selectedPlaceID: String?
    @State private var placeKind = PlaceAssociationKind.mentioned
    @State private var showMap = false
    @State private var camera: MapCameraPosition = .automatic
    private var displayedPoems: [Poem] {
        guard let selectedPlaceID else { return poems }
        return places.first(where: { $0.id == selectedPlaceID })?.poems ?? []
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                TextField("搜标题、诗句或诗人", text: $state.keyword)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("explore.search")
                ForEach(ExplorationGroup.allCases) { group in
                    DisclosureGroup(isExpanded: Binding(get: { expanded.contains(group) }, set: { if $0 { expanded.insert(group) } else { expanded.remove(group) } })) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], alignment: .leading) {
                            ForEach(options[group, default: []], id: \.self) { value in
                                Button { state.toggle(value, in: group) } label: {
                                    Text(value).frame(maxWidth: .infinity, minHeight: 44)
                                        .background(state.selections[group, default: []].contains(value) ? PoetryStyle.accent.opacity(0.12) : Color.clear)
                                }.accessibilityAddTraits(state.selections[group, default: []].contains(value) ? .isSelected : [])
                            }
                        }
                    } label: {
                        Text(group.rawValue + (state.selections[group, default: []].isEmpty ? "" : " · \(state.selections[group, default: []].count)"))
                    }
                }
                ForEach(ExplorationGroup.allCases) { group in
                    ForEach(state.selections[group, default: []].sorted(), id: \.self) { value in
                        Button { state.toggle(value, in: group) } label: { Label("\(group.rawValue)：\(value)", systemImage: "xmark.circle") }.frame(minHeight: 44)
                    }
                }
                if !state.keyword.isEmpty || state.selections.values.contains(where: { !$0.isEmpty }) {
                    Button("清空条件") { state.clear() }.frame(minHeight: 44)
                }
                placeBrowser
                if let failure { Text(failure).foregroundStyle(.secondary) }
                Text("\(displayedPoems.count) 首作品").font(.caption).foregroundStyle(.secondary)
                if displayedPoems.isEmpty {
                    ContentUnavailableView {
                        Label("没有符合条件的作品", systemImage: "magnifyingglass")
                    } description: { Text("已保留搜索与筛选，可移除条件或展开分组调整。") } actions: {
                        Button("调整筛选") { expanded = Set(ExplorationGroup.allCases) }
                    }
                }
                ForEach(displayedPoems) { poem in
                    NavigationLink {
                        ReadingDestination(application: application, poem: poem)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(poem.title).font(.system(.title3, design: .serif))
                            Text("\(poem.dynasty) · \(poem.poet)").font(.caption).foregroundStyle(.secondary)
                            Text(poem.lines.first ?? "").font(.system(.body, design: .serif)).foregroundStyle(.secondary)
                            Divider()
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.id(poem.id)
                }
            }.padding(28).scrollTargetLayout()
        }.scrollPosition(id: $state.visiblePoemID, anchor: .top)
            .background(PoetryStyle.paper).foregroundStyle(PoetryStyle.ink)
            .navigationTitle("探索")
            .onChange(of: state.keyword) { _, _ in state.visiblePoemID = nil }
            .onChange(of: state) { old, new in
                guard loaded else { return }
                do {
                    if old.keyword != new.keyword || old.selections != new.selections { poems = try application.explore(new); places = try application.explorePlaces(new, kind: placeKind) }
                    try application.saveExploration(new)
                    failure = nil
                } catch { failure = error.localizedDescription }
            }
            .onChange(of: placeKind) { _, _ in
                selectedPlaceID = nil
                do { places = try application.explorePlaces(state, kind: placeKind) }
                catch { failure = error.localizedDescription }
            }
            .task {
                guard !loaded else { return }
                do {
                    state = try application.restoreExploration()
                    options = try application.explorationOptions()
                    poems = try application.explore(state)
                    places = try application.explorePlaces(state, kind: placeKind)
                    loaded = true
                } catch { failure = error.localizedDescription }
            }
    }
    private var placeBrowser: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("从地点读诗").font(.headline)
            Picker("地点关联", selection: $placeKind) {
                ForEach(PlaceAssociationKind.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("显示地图", isOn: $showMap).accessibilityIdentifier("places.map")
            if showMap {
                Map(position: $camera) {
                    ForEach(places) { result in
                        if let region = result.place.region {
                            MapPolygon(coordinates: [
                                CLLocationCoordinate2D(latitude: region.south, longitude: region.west),
                                CLLocationCoordinate2D(latitude: region.north, longitude: region.west),
                                CLLocationCoordinate2D(latitude: region.north, longitude: region.east),
                                CLLocationCoordinate2D(latitude: region.south, longitude: region.east)
                            ]).foregroundStyle(PoetryStyle.accent.opacity(0.12))
                                .stroke(PoetryStyle.accent.opacity(0.5), lineWidth: 1)
                            Annotation(result.place.name + " · 范围示意", coordinate: CLLocationCoordinate2D(latitude: (region.north + region.south) / 2, longitude: (region.west + region.east) / 2)) {
                                Button(result.place.name + " · 今地范围示意") { selectedPlaceID = result.id }
                                    .padding(8).background(PoetryStyle.paper).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }.frame(height: 250)
                Text("框线是现代区域范围示意，不是精确边界或历史坐标。底图需联网；不可用时仍可使用下方离线地点与作品。").font(.caption).foregroundStyle(.secondary)
            }
            if places.isEmpty {
                Text(placeKind == .composition ? "当前作品没有已核实的写作地，仍可在下方读诗。" : "当前条件下没有已核实的地点，仍可在下方读诗。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(places) { result in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        selectedPlaceID = result.id
                        if let r = result.place.region {
                            camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (r.north + r.south) / 2, longitude: (r.west + r.east) / 2), span: MKCoordinateSpan(latitudeDelta: (r.north - r.south) * 1.3, longitudeDelta: (r.east - r.west) * 1.3)))
                        }
                    } label: {
                        Label("\(result.place.name) · \(result.poems.count) 首", systemImage: selectedPlaceID == result.id ? "checkmark.circle" : "map")
                    }.frame(minHeight: 44).accessibilityIdentifier("places." + result.id)
                    Text(result.place.precision).font(.caption)
                    DisclosureGroup("地点依据与不确定性") {
                        Text(result.place.caveat).font(.caption)
                        evidenceLink(result.place.geography)
                        ForEach(Array(result.associations.enumerated()), id: \.offset) { _, association in evidenceLink(association.evidence) }
                    }
                }
            }
            if selectedPlaceID != nil {
                Button("取消地点筛选") { selectedPlaceID = nil }.frame(minHeight: 44)
                    .accessibilityIdentifier("places.clear")
            }
        }
    }
    private func evidenceLink(_ evidence: SourceEvidence) -> some View {
        VStack(alignment: .leading) {
            Text(evidence.note).font(.caption)
            if let url = URL(string: evidence.url) { Link(evidence.title, destination: url).font(.caption) }
        }
    }

}
