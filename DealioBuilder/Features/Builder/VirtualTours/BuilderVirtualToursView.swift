import SwiftUI

private struct Tour: Identifiable { let id = UUID(); let label: String; let url: String }

private func parseTours(_ videoUrl: String?) -> [Tour] {
    guard let videoUrl, !videoUrl.isEmpty else { return [] }
    if let data = videoUrl.data(using: .utf8),
       let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        return arr.map { Tour(label: ($0["label"] as? String) ?? "Tour", url: ($0["url"] as? String) ?? "") }
    }
    return [Tour(label: "Project Video", url: videoUrl)]
}

private func youtubeThumb(_ url: String) -> URL? {
    guard let match = url.range(of: #"(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/|youtube\.com/shorts/)([^&?/\s]+)"#, options: .regularExpression) else { return nil }
    let id = url[match].split(whereSeparator: { "/=".contains($0) }).last.map(String.init) ?? ""
    return URL(string: "https://img.youtube.com/vi/\(id)/mqdefault.jpg")
}

struct BuilderVirtualToursView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderProjectsListModel()
    @State private var selectedId: Int?

    private var project: Project? { model.projects.first { $0.id == selectedId } ?? model.projects.first }

    var body: some View {
        VStack(spacing: 0) {
            if !model.projects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.projects) { p in
                            Button { selectedId = p.id } label: {
                                Text(p.name).font(.subheadline.weight(project?.id == p.id ? .semibold : .regular))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(project?.id == p.id ? Color.brandTeal : Color(.secondarySystemGroupedBackground), in: Capsule())
                                    .foregroundStyle(project?.id == p.id ? .white : Color.dealioTextSecondary)
                            }.buttonStyle(.plain)
                        }
                    }.padding()
                }
            }
            let tours = parseTours(project?.videoUrl)
            Group {
                if model.loading { ProgressView().frame(maxHeight: .infinity) }
                else if tours.isEmpty {
                    ContentUnavailableView("No tours for this project", systemImage: "play.rectangle",
                        description: Text("Walkthrough videos added on the web appear here."))
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(tours) { tour in
                                Link(destination: URL(string: tour.url) ?? URL(string: "https://dealio.app")!) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ZStack {
                                            Color.dealioNavyMid
                                            if let thumb = youtubeThumb(tour.url) {
                                                AsyncImage(url: thumb) { $0.resizable().scaledToFill() } placeholder: { Color.dealioNavyMid }
                                            }
                                            Image(systemName: "play.circle.fill").font(.system(size: 50)).foregroundStyle(.white)
                                        }
                                        .frame(height: 180).clipped()
                                        HStack {
                                            Text(tour.label).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
                                        }.padding(14)
                                    }
                                    .cardSurface()
                                }
                            }
                        }.padding()
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Virtual Tours")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}

/// Shared loader for the builder project list (used by tours, RERA, etc.).
@MainActor
final class BuilderProjectsListModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var loading = true
    func load(builderId: Int) async {
        loading = projects.isEmpty
        projects = (try? await APIClient.shared.get("/builder/\(builderId)/projects")) ?? []
        loading = false
    }
}
