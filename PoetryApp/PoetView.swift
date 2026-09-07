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
                    NavigationLink {
                        LifeTimelineView(application: application, poetID: poetID)
                    } label: { Text("生平路线").frame(minHeight: 44) }
                    .accessibilityIdentifier("poet-life")
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

struct LifeTimelineView: View {
    let application: PoetryApplication
    let poetID: String
    @State private var timeline: LifeTimeline?
    @State private var poems: [String: Poem] = [:]
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("生平路线").font(.system(.title, design: .serif))
                Text("仅呈现已有资料支持的阶段；顺序不代表精确年份，也不表示完整行程。")
                    .font(.footnote).foregroundStyle(.secondary)
                if let timeline {
                    if timeline.isEmpty { Text("这位诗人的生平资料暂未收录。").accessibilityIdentifier("life-empty") }
                    ForEach(timeline.ordered) { event in eventView(event) }
                    if !timeline.undated.isEmpty {
                        Text("时间先后未定").font(.headline)
                        Text("以下经历有来源，尚不能确定在路线中的位置。").font(.footnote)
                        ForEach(timeline.undated) { event in eventView(event) }
                    }
                } else if let failure { Text("暂时无法读取生平资料：\(failure)") }
                else { ProgressView("读取生平资料") }
            }.padding(28)
        }.background(PoetryStyle.paper).foregroundStyle(PoetryStyle.ink)
            .navigationTitle("生平").navigationBarTitleDisplayMode(.inline)
            .task {
                do {
                    poems = Dictionary(uniqueKeysWithValues: try application.allPoems().map { ($0.id, $0) })
                    timeline = try application.lifeTimeline(poetID: poetID)
                } catch { failure = error.localizedDescription }
            }
    }

    private func eventView(_ event: LifeEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.period).font(.subheadline).foregroundStyle(.secondary)
            Text(event.title).font(.headline)
            if event.uncertainty != nil { Text("时间或记载有说明").font(.caption).foregroundStyle(.secondary) }
            DisclosureGroup("事件依据与时间说明") {
                if let note = event.uncertainty { Text(note).padding(.top, 8) }
                evidence(event.sources)
            }.frame(minHeight: 44)
            if event.poemLinks.isEmpty { Text("暂未建立有依据的作品关联。").font(.footnote).foregroundStyle(.secondary) }
            ForEach(Array(event.poemLinks.enumerated()), id: \.offset) { _, link in
                Text(link.kind.label).font(.subheadline)
                Text(link.kind.explanation).font(.footnote).foregroundStyle(.secondary)
                if let poem = poems[link.poemID] {
                    NavigationLink {
                        ReadingDestination(application: application, poem: poem)
                    } label: { Text(poem.title).frame(minHeight: 44) }
                    .accessibilityIdentifier("life-poem-\(event.id)-\(poem.id)")
                } else { Text("对应作品暂未收录。").font(.footnote) }
                DisclosureGroup("作品关联依据") { evidence(link.sources) }.frame(minHeight: 44)
            }
            Divider()
        }.accessibilityIdentifier("life-event-\(event.id)")
    }

    private func evidence(_ sources: [SourceEvidence]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if sources.isEmpty { Text("来源暂未收录。") }
            ForEach(sources, id: \.self) { source in
                Text(source.title); Text(source.note); Text(source.license)
                if let url = URL(string: source.url) { Link("查看来源网页（需联网）", destination: url).frame(minHeight: 44) }
            }
        }.font(.footnote).padding(.top, 8)
    }
}
