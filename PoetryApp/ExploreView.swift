import SwiftUI
import PoetryCore

struct ExploreView: View {
    let application: PoetryApplication
    @State private var state = ExplorationState()
    @State private var poems: [Poem] = []
    @State private var options: [ExplorationGroup: [String]] = [:]
    @State private var expanded = Set<ExplorationGroup>()
    @State private var failure: String?
    @State private var loaded = false

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
                if let failure { Text(failure).foregroundStyle(.secondary) }
                Text("\(poems.count) 首作品").font(.caption).foregroundStyle(.secondary)
                if poems.isEmpty {
                    ContentUnavailableView {
                        Label("没有符合条件的作品", systemImage: "magnifyingglass")
                    } description: { Text("已保留搜索与筛选，可移除条件或展开分组调整。") } actions: {
                        Button("调整筛选") { expanded = Set(ExplorationGroup.allCases) }
                    }
                }
                ForEach(poems) { poem in
                    NavigationLink {
                        PoemReaderView(poem: poem) { EmptyView() }
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
                    if old.keyword != new.keyword || old.selections != new.selections { poems = try application.explore(new) }
                    try application.saveExploration(new)
                    failure = nil
                } catch { failure = error.localizedDescription }
            }
            .task {
                guard !loaded else { return }
                do {
                    state = try application.restoreExploration()
                    options = try application.explorationOptions()
                    poems = try application.explore(state)
                    loaded = true
                } catch { failure = error.localizedDescription }
            }
    }
}
