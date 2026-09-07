import SwiftUI
import PoetryCore

/// One instance at the root is inherited by every reader and collection page.
@MainActor
final class CollectionStore: ObservableObject {
    let application: PoetryApplication
    @Published private(set) var favorites: [FavoritePoem] = []
    @Published var failure: String?

    init(application: PoetryApplication) {
        self.application = application
        refresh()
    }

    func refresh() {
        do { favorites = try application.favoritePoems(); failure = nil }
        catch { failure = error.localizedDescription }
    }

    func isFavorite(id: String) -> Bool { favorites.contains { $0.id == id } }

    func toggle(_ poem: Poem) {
        do {
            if try application.isFavorite(id: poem.id) { try application.removeFavorite(id: poem.id) }
            else { try application.saveFavorite(poem) }
            refresh()
        } catch { failure = error.localizedDescription }
    }

    func remove(id: String) {
        do { try application.removeFavorite(id: id); refresh() }
        catch { failure = error.localizedDescription }
    }
}

struct FavoriteButton: View {
    @EnvironmentObject private var collection: CollectionStore
    let poem: Poem
    var body: some View {
        Button { collection.toggle(poem) } label: {
            Label(collection.isFavorite(id: poem.id) ? "取消收藏" : "收藏整首作品", systemImage: collection.isFavorite(id: poem.id) ? "bookmark.fill" : "bookmark")
                .frame(minWidth: 44, minHeight: 44)
        }
        .alert("收藏未能完成", isPresented: Binding(get: { collection.failure != nil }, set: { if !$0 { collection.failure = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(collection.failure ?? "请稍后重试") }
    }
}
