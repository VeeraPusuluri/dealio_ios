import SwiftUI

@MainActor
final class BuilderDocumentsModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var documents: [ProjectDocument] = []
    @Published var selectedProjectId: Int?
    @Published var loading = true
    @Published var error: String?

    private var builderId = 0

    func start(builderId: Int) async {
        self.builderId = builderId
        loading = projects.isEmpty
        do {
            projects = try await APIClient.shared.get("/builder/\(builderId)/projects")
            if selectedProjectId == nil { selectedProjectId = projects.first?.id }
        } catch { self.error = authMessage(error) }
        await loadDocs()
        loading = false
    }

    func loadDocs() async {
        guard let pid = selectedProjectId else { documents = []; return }
        documents = (try? await APIClient.shared.get("/builder/\(builderId)/projects/\(pid)/documents")) ?? []
    }
}

struct BuilderDocumentsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDocumentsModel()

    var body: some View {
        VStack(spacing: 0) {
            if !model.projects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.projects) { project in
                            Button {
                                model.selectedProjectId = project.id
                                Task { await model.loadDocs() }
                            } label: {
                                Text(project.name)
                                    .font(.subheadline.weight(model.selectedProjectId == project.id ? .semibold : .regular))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(model.selectedProjectId == project.id ? Color.brandTeal : Color(.secondarySystemGroupedBackground), in: Capsule())
                                    .foregroundStyle(model.selectedProjectId == project.id ? .white : Color.dealioTextSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }

            Group {
                if model.loading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if model.documents.isEmpty {
                    ContentUnavailableView("No documents", systemImage: "folder",
                        description: Text("RERA certificates, deeds, floor plans and brochures uploaded on the web appear here."))
                } else {
                    List(model.documents) { doc in
                        Link(destination: doc.fileURL ?? URL(string: "https://dealio.app")!) {
                            HStack(spacing: 12) {
                                IconBadge(systemImage: "doc.text", tint: .brandTeal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.name ?? "Document").font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text(doc.docType ?? "—").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.start(builderId: id) } }
    }
}
