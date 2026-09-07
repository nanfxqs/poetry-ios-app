import SwiftUI
import PoetryCore

@main
struct PoetryApp: App {
    @State private var application: PoetryApplication?
    @State private var failure: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if let application { RootView(application: application) }
                else if let failure { ContentUnavailableView("暂时无法打开诗词", systemImage: "book.closed", description: Text(failure)) }
                else { ProgressView("打开诗词").task { open() } }
            }.tint(PoetryStyle.accent)
        }
    }
    private func open() {
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            application = try PoetryApplication(databaseURL: directory.appendingPathComponent("poetry.sqlite"))
        } catch { failure = error.localizedDescription }
    }
}

enum PoetryStyle {
    static let paper = Color(red: 250/255, green: 250/255, blue: 248/255)
    static let ink = Color(red: 48/255, green: 46/255, blue: 44/255)
    static let accent = Color(red: 156/255, green: 73/255, blue: 70/255)
}

struct RootView: View {
    let application: PoetryApplication
    var body: some View {
        TabView {
            NavigationStack { TodayView(application: application) }.tabItem { Label("今日", systemImage: "sun.max") }
            NavigationStack { ContentUnavailableView("探索", systemImage: "map", description: Text("地点与诗人资料尚未接入。你可以先在今日阅读随包作品。")) }.tabItem { Label("探索", systemImage: "map") }
            NavigationStack { ContentUnavailableView("诗集", systemImage: "books.vertical", description: Text("收藏功能尚未接入。随包作品已可离线阅读。")) }.tabItem { Label("诗集", systemImage: "books.vertical") }
        }
    }
}

struct TodayView: View {
    let application: PoetryApplication
    @State private var poems: [Poem] = []
    @State private var failure: String?
    var body: some View {
        Group {
            if let first = poems.first {
                PoemReaderView(poem: first) {
                    if poems.count > 1 {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("随包作品").font(.headline)
                            ForEach(poems.dropFirst()) { poem in
                                NavigationLink { PoemReaderView(poem: poem) { EmptyView() } } label: {
                                    VStack(alignment: .leading, spacing: 5) { Text(poem.title); Text(poem.poet).font(.caption).foregroundStyle(.secondary) }
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            } else { ContentUnavailableView("暂无作品", systemImage: "book", description: Text(failure ?? "随包作品为空")) }
        }.navigationTitle("今日").navigationBarTitleDisplayMode(.inline)
            .task { do { poems = try application.allPoems() } catch { failure = error.localizedDescription } }
    }
}

struct PoemReaderView<Footer: View>: View {
    let poem: Poem
    @ViewBuilder let footer: () -> Footer
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Original geometric ink motif: atmosphere only, no historical reconstruction.
                HStack { Spacer(); Image(systemName: "cloud.fog").font(.system(size: 50, weight: .ultraLight)).foregroundStyle(PoetryStyle.ink.opacity(0.16)).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: 12) {
                    Text(poem.title).font(.system(.title2, design: .serif)).fixedSize(horizontal: false, vertical: true)
                    Text("\(poem.dynasty) · \(poem.poet)").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(poem.lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.title2, design: .serif)).lineSpacing(10).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                Divider()
                DisclosureGroup("背景与译注") {
                    Text(poem.background ?? "这首作品暂未收录已核定的背景与译注。可在来源中查看原文依据。").font(.body).padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minHeight: 44)
                DisclosureGroup("来源与版本") {
                    ForEach(poem.sources, id: \.self) { source in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(source.title); Text(source.license); Text(source.note)
                            if let url = URL(string: source.url) { Link("查看来源网页（需联网）", destination: url).frame(minHeight: 44) }
                        }.font(.footnote).padding(.top, 12)
                    }
                }.frame(minHeight: 44)
                footer()
            }.padding(.horizontal, 28).padding(.vertical, 24)
        }.background(PoetryStyle.paper).foregroundStyle(PoetryStyle.ink)
    }
}
