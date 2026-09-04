import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class BuilderDocumentsModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var documents: [ProjectDocument] = []
    @Published var selectedProjectId: Int?
    @Published var loading = true
    @Published var uploading = false
    @Published var error: String?
    @Published var message: String?

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

    /// The type travels with the file because the buyer's project page sorts on
    /// it: a floor plan goes to the plans carousel, a photograph to the gallery,
    /// anything else to the downloads list.
    func upload(_ url: URL, docType: String) async {
        guard let pid = selectedProjectId else { return }
        uploading = true
        defer { uploading = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            message = "Could not read that file. Try another."
            return
        }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        do {
            let _: ProjectDocument = try await APIClient.shared.upload(
                "/builder/\(builderId)/projects/\(pid)/documents",
                fileData: data, fileName: url.lastPathComponent, mimeType: mime,
                fields: ["docType": docType]
            )
            message = "\(docType) uploaded"
            await loadDocs()
        } catch { message = authMessage(error) }
    }
}

private let builderDocTypes = ["Brochure", "Floor Plan", "Tower Plan", "Photo",
                               "RERA Certificate", "Price List", "Approval", "Other"]

struct BuilderDocumentsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDocumentsModel()
    @State private var pickingType: String?
    @State private var showTypePicker = false

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
                        description: Text("Upload the RERA certificate, floor plans and brochures buyers ask for."))
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.uploading {
                    ProgressView().controlSize(.small)
                } else {
                    Button { showTypePicker = true } label: { Label("Upload", systemImage: "plus") }
                        .disabled(model.selectedProjectId == nil)
                }
            }
        }
        .task { if let id = await auth.resolvedBuilderId() { await model.start(builderId: id) } }
        .confirmationDialog("What is this document?", isPresented: $showTypePicker, titleVisibility: .visible) {
            ForEach(builderDocTypes, id: \.self) { type in
                Button(type) { pickingType = type }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: Binding(get: { pickingType != nil },
                                           set: { if !$0 { pickingType = nil } }),
                      allowedContentTypes: [.pdf, .image, .data],
                      allowsMultipleSelection: false) { result in
            let type = pickingType
            pickingType = nil
            if case .success(let urls) = result, let url = urls.first, let type {
                Task { await model.upload(url, docType: type) }
            }
        }
        .alert("Documents", isPresented: Binding(get: { model.message != nil },
                                                 set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}
