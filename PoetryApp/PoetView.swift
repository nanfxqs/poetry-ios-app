import SwiftUI
import PoetryCore

struct PoetView: View {
    let application: PoetryApplication
    let poetID: String
    @State private var overview: PoetOverview?
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let overview {
                    if let poet = overview.poet {
                        Text("\(poet.dynasty) · \(poet.name)").font(.system(.title, design: .serif))
                        Text(overview.biographyUnavailable ? "这位诗人的概要暂未收录。" : (poet.biography ?? ""))
                            .lineSpacing(8).textSelection(.enabled)
                        DisclosureGroup("人物资料来源") {
                            if poet.sources.isEmpty { Text("人物资料来源暂未收录。").padding(.top, 12) }
                            ForEach(poet.sources, id: \.self) { source in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(source.title); Text(source.note); Text(source.license)
                                    if let url = URL(string: source.url) { Link("查看来源网页（需联网）", destination: url).frame(minHeight: 44) }
                                }.font(.footnote).padding(.top, 12)
                            }
                        }.frame(minHeight: 44)
                    } else {
                        Text("诗人资料暂未收录").font(.headline)
                        Text("仍可阅读下方已收录的作品。").foregroundStyle(.secondary)
                    }
                    Divider()
                    Text("已收录作品 · \(overview.works.count) 首").font(.headline)
                    Text("仅展示本应用已收录的作品，非完整全集。").font(.footnote).foregroundStyle(.secondary)
                    if overview.works.isEmpty { Text("暂未收录这位诗人的作品。").foregroundStyle(.secondary) }
                    ForEach(overview.works) { poem in
                        NavigationLink {
                            ReadingDestination(application: application, poem: poem)
                        } label: {
                            Text(poem.title).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.accessibilityIdentifier("poet-work-\(poem.id)")
                        Divider()
                    }
                } else if let failure {
                    ContentUnavailableView("暂时无法读取诗人资料", systemImage: "person", description: Text(failure))
                } else { ProgressView("读取诗人资料") }
            }.padding(28)
        }.background(PoetryStyle.paper).foregroundStyle(PoetryStyle.ink)
            .navigationTitle(overview?.poet?.name ?? "诗人").navigationBarTitleDisplayMode(.inline)
            .task {
                do { overview = try application.poetOverview(id: poetID) }
                catch { failure = error.localizedDescription }
            }
    }
}

struct PoetDirectoryView: View {
    let application: PoetryApplication
    @State private var poets: [Poet] = []
    @State private var failure: String?

    var body: some View {
        List {
            if let failure {
                Text(failure).foregroundStyle(.secondary)
            } else if poets.isEmpty {
                Text("暂未收录诗人资料。").foregroundStyle(.secondary)
            }
            ForEach(poets) { poet in
                NavigationLink {
                    PoetView(application: application, poetID: poet.id)
                } label: {
                    Text("\(poet.dynasty) · \(poet.name)").frame(minHeight: 44)
                }
            }.listRowBackground(PoetryStyle.paper)
        }.scrollContentBackground(.hidden).background(PoetryStyle.paper)
            .navigationTitle("诗人")
            .task {
                do { poets = try application.allPoets() }
                catch { failure = "暂时无法读取诗人资料：\(error.localizedDescription)" }
            }
    }
}
