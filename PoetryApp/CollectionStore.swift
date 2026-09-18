import SwiftUI
import PoetryCore

/// One instance at the root is inherited by every reader and collection page.
@MainActor
final class CollectionStore: ObservableObject {
    let application: PoetryApplication
    @Published private(set) var favorites: [FavoritePoem] = []
    @Published var failure: String?
    @Published private(set) var backupMessage = "尚未备份"
    @Published private(set) var backupBusy = false
    @Published private(set) var restorePreview: CollectionBackupReceipt?

    func attemptBackup() async {
        guard !backupBusy else { return }
        backupBusy = true
        defer { backupBusy = false }
        do {
            guard let credentials = try PoetryServiceSettings.load() else { backupMessage = "请在个人服务设置连接；收藏已保存在本机。"; return }
            let client = CollectionBackupClient(credentials: credentials)
            while try application.collectionBackupStatus().pending {
                let sent = try application.collectionSnapshot()
                let receipt = try await client.upload(sent)
                try application.acknowledgeCollectionBackup(receipt, sent: sent)
            }
            showBackupStatus()
        } catch { backupMessage = "备份未完成，收藏保留在本机。请重试；新安装可先查看远端备份。" }
    }
    private func showBackupStatus() {
        if let status = try? application.collectionBackupStatus() {
            if status.pending { backupMessage = "收藏已保存，待备份。" }
            else if let date = status.lastSuccess { backupMessage = "最近成功备份：" + date.formatted(date: .abbreviated, time: .shortened) }
            else { backupMessage = "尚未备份；新安装请主动查看远端备份。" }
        }
    }
    func previewRestore() async {
        guard !backupBusy else { return }
        backupBusy = true
        restorePreview = nil
        defer { backupBusy = false }
        do {
            guard let credentials = try PoetryServiceSettings.load() else { throw ContentUpdateError.unavailable }
            restorePreview = try await CollectionBackupClient(credentials: credentials).fetch()
        } catch { backupMessage = "无法取得备份，请检查连接后重试。当前收藏未改动。" }
    }
    func restore() {
        guard !backupBusy, let receipt = restorePreview else { return }
        do {
            try application.restoreCollection(receipt)
            restorePreview = nil
            refresh()
            showBackupStatus()
        } catch { backupMessage = "恢复失败，当前收藏未改动。" }
    }


    init(application: PoetryApplication) {
        self.application = application
        refresh()
        showBackupStatus()
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
            showBackupStatus()
            Task { await attemptBackup() }
        } catch { failure = error.localizedDescription }
    }

    func remove(id: String) {
        do { try application.removeFavorite(id: id); refresh(); showBackupStatus(); Task { await attemptBackup() } }
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
