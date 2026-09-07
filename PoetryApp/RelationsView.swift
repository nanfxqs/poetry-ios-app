import SwiftUI
import PoetryCore

struct RelationsView: View {
    let application: PoetryApplication
    let poetID: String
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var neighborhood: RelationshipNeighborhood?
    @State private var selectedPerson: String?
    @State private var selectedRelationship: String?
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let neighborhood {
                    Text("以\(neighborhood.center?.name ?? "当前诗人")为中心").font(.title2)
                    Text("按朝代分组 · \(neighborhood.center?.dynasty ?? "未收录")").font(.footnote).foregroundStyle(.secondary)
                    if neighborhood.relationships.isEmpty {
                        Text("暂未收录已核定的人物关系。没有连线不代表没有交往，仍可阅读作品。")
                        ForEach(neighborhood.works) { poem in
                            NavigationLink(poem.title) { ReadingDestination(application: application, poem: poem) }.frame(minHeight: 44)
                        }
                    } else {
                        if !typeSize.isAccessibilitySize && neighborhood.people.count <= 5 {
                            graph(neighborhood).frame(height: 320)
                        }
                        Text("人物").font(.headline)
                        ForEach(neighborhood.people) { person in
                            HStack {
                                Button { selectedPerson = person.id; selectedRelationship = nil } label: {
                                    Text(person.name).frame(minWidth: 80, minHeight: 44, alignment: .leading)
                                }.accessibilityIdentifier("relation-person-\(person.id)")
                                Spacer()
                                NavigationLink("查看人物") { PoetView(application: application, poetID: person.id) }.frame(minHeight: 44)
                            }
                        }
                        Text("作品中的联系").font(.headline)
                        Text("点选人物可高亮联系；点选连线或下方条目查看依据。").font(.footnote)
                        ForEach(neighborhood.relationships) { relation in
                            Button { selectedRelationship = relation.id; selectedPerson = nil } label: {
                                Text(title(relation, neighborhood)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .fontWeight(highlighted(relation) ? .bold : .regular)
                            }.accessibilityIdentifier("relation-edge-\(relation.id)")
                            if selectedRelationship == relation.id { evidence(relation) }
                            Divider()
                        }
                    }
                } else if let failure { Text(failure) }
                else { ProgressView("读取人物关系") }
            }.padding(28)
        }.background(PoetryStyle.paper).foregroundStyle(PoetryStyle.ink)
            .navigationTitle("人物关系").navigationBarTitleDisplayMode(.inline)
            .task {
                do { neighborhood = try application.relationshipNeighborhood(poetID: poetID) }
                catch { failure = "暂时无法读取人物关系：\(error.localizedDescription)" }
            }
    }

    private func title(_ relation: Relationship, _ graph: RelationshipNeighborhood) -> String {
        let from = graph.people.first { $0.id == relation.fromPoetID }?.name ?? "未收录"
        let to = graph.people.first { $0.id == relation.toPoetID }?.name ?? "未收录"
        return "\(from) → \(to) · \(relation.kind)"
    }

    private func highlighted(_ relation: Relationship) -> Bool {
        selectedRelationship == relation.id || selectedPerson == relation.fromPoetID || selectedPerson == relation.toPoetID
    }

    private func graph(_ graph: RelationshipNeighborhood) -> some View {
        GeometryReader { geometry in
            let positions = positions(graph, size: geometry.size)
            ZStack {
                ForEach(graph.relationships) { relation in
                    if let from = positions[relation.fromPoetID], let to = positions[relation.toPoetID] {
                        let line = Path { path in path.move(to: from); path.addLine(to: to) }
                        line.stroke(highlighted(relation) ? Color.accentColor : Color.secondary, lineWidth: highlighted(relation) ? 3 : 1)
                            .contentShape(line.strokedPath(StrokeStyle(lineWidth: 44)))
                            .onTapGesture { selectedRelationship = relation.id; selectedPerson = nil }
                            .accessibilityHidden(true)
                    }
                }
                ForEach(graph.people) { person in
                    if let position = positions[person.id] {
                        Button { selectedPerson = person.id; selectedRelationship = nil } label: {
                            Text(person.name).font(.system(.body, design: .serif)).fixedSize()
                                .padding(12).background(PoetryStyle.paper, in: Capsule())
                                .overlay(Capsule().stroke(selectedPerson == person.id ? Color.accentColor : Color.secondary))
                        }.position(position).accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func positions(_ graph: RelationshipNeighborhood, size: CGSize) -> [String: CGPoint] {
        var result = [poetID: CGPoint(x: size.width / 2, y: size.height / 2)]
        let others = graph.people.filter { $0.id != poetID }
        for (index, person) in others.enumerated() {
            let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(others.count)
            result[person.id] = CGPoint(x: size.width / 2 + cos(angle) * max(0, size.width / 2 - 52), y: size.height / 2 + sin(angle) * 115)
        }
        return result
    }

    private func evidence(_ relation: Relationship) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(relation.summary).textSelection(.enabled)
            ForEach(relation.evidencePoemIDs, id: \.self) { id in
                if let poem = try? application.readPoem(id: id) {
                    NavigationLink("读《\(poem.title)》") { ReadingDestination(application: application, poem: poem) }
                        .frame(minHeight: 44).accessibilityIdentifier("relation-evidence-\(id)")
                }
            }
            ForEach(relation.sources, id: \.self) { source in
                VStack(alignment: .leading, spacing: 8) {
                    Text(source.title); Text(source.note); Text(source.license)
                    if let url = URL(string: source.url) { Link("查看来源网页（需联网）", destination: url).frame(minHeight: 44) }
                }.font(.footnote)
            }
        }
    }
}
