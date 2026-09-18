import SwiftUI
import PoetryCore

struct CollectionView: View {
    @ObservedObject var store: CollectionStore
    let goToday: () -> Void
    @State private var search = ""
    // Value destinations outlive their list row when a reader removes a favorite.
    @State private var path: [Poem] = []
    private var matches: [FavoritePoem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.favorites.filter { favorite in
            query.isEmpty || ([favorite.poem.title, favorite.poem.poet] + favorite.poem.lines).contains { $0.localizedStandardContains(query) }
        }
    }
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.favorites.isEmpty {
                    ContentUnavailableView {
                        Label("诗集尚空", systemImage: "books.vertical")
                    } description: { Text("收藏喜欢的整首作品，在这里重读。") } actions: {
                        Button("去读今日诗词", action: goToday).frame(minHeight: 44)
                    }
                } else {
                    List {
                        Text("共 \(store.favorites.count) 首 · 最近收藏优先").font(.subheadline).foregroundStyle(.secondary)
                        if matches.isEmpty { ContentUnavailableView.search(text: search) }
                        ForEach(matches) { favorite in
                            NavigationLink(value: favorite.poem) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(favorite.poem.title).font(.system(.headline, design: .serif)).fixedSize(horizontal: false, vertical: true)
                                    Text(favorite.poem.poet).font(.subheadline).foregroundStyle(.secondary)
                                    if let line = favorite.poem.lines.first { Text(line).font(.system(.body, design: .serif)).foregroundStyle(.secondary) }
                                }.padding(.vertical, 8)
                            }.swipeActions { Button("取消收藏", role: .destructive) { store.remove(id: favorite.id) } }
                                .contextMenu { Button("取消收藏", role: .destructive) { store.remove(id: favorite.id) } }
                        }.listRowBackground(PoetryStyle.paper)
                    }.scrollContentBackground(.hidden)
                }
            }
            .background(PoetryStyle.paper)
            .navigationTitle("诗集")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("更新与备份") { ServiceSettingsView(application: store.application) }
                }
            }
            .searchable(text: $search, prompt: "在收藏中搜索标题、诗句或诗人")
            .navigationDestination(for: Poem.self) { poem in ReadingDestination(application: store.application, poem: poem) }
            .alert("诗集暂时无法更新", isPresented: Binding(get: { store.failure != nil }, set: { if !$0 { store.failure = nil } })) {
                Button("重试") { store.refresh() }
                Button("取消", role: .cancel) {}
            } message: { Text(store.failure ?? "请稍后重试") }
        }
    }
}
