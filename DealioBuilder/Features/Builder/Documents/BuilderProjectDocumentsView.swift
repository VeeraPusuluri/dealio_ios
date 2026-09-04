import SwiftUI
import UniformTypeIdentifiers

/// A project's documents — brochures, floor plans, approvals — and the upload
/// that adds one.
///
/// The type travels with the file because the buyer's project page sorts on it:
/// a floor plan is drawn into the plans carousel, a photograph into the gallery,
/// everything else into the downloads list. Mirrors the Android project page's
/// documents section.
struct BuilderProjectDocumentsView: View {
    let project: Project

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL

    @State private var documents: [ProjectDocument] = []
    @State private var loading = true
    @State private var uploading = false
    @State private var error: String?
    @State private var message: String?
    @State private var pickingType: String?
    @State private var showTypePicker = false

    private static let docTypes = ["Brochure", "Floor Plan", "Tower Plan", "Photo",
                                   "RERA Certificate", "Price List", "Approval", "Other"]

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, documents.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await load() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else if documents.isEmpty {
                ContentUnavailableView("No documents yet", systemImage: "folder",
                    description: Text("Upload the brochure, floor plans and approvals buyers ask for."))
            } else {
                List(documents) { document in
                    Button {
                        if let url = document.fileURL { openURL(url) }
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemImage: icon(document.docType), tint: .brandTeal, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.name?.nilIfEmpty ?? document.docType?.nilIfEmpty ?? "Document")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dealioTextPrimary)
                                Text([document.docType, document.createdAt.map { String($0.prefix(10)) }]
                                        .compactMap { $0?.nilIfEmpty }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square").foregroundStyle(Color.dealioTextSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if uploading { ProgressView().controlSize(.small) }
                else { Button { showTypePicker = true } label: { Label("Upload", systemImage: "plus") } }
            }
        }
        .task { await load() }
        .confirmationDialog("What is this document?", isPresented: $showTypePicker, titleVisibility: .visible) {
            ForEach(Self.docTypes, id: \.self) { type in
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
                Task { await upload(url, docType: type) }
            }
        }
        .alert("Documents", isPresented: Binding(get: { message != nil },
                                                 set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func load() async {
        guard let builderId = project.builderId ?? auth.builderId else { loading = false; return }
        loading = documents.isEmpty
        error = nil
        do {
            documents = try await APIClient.shared.get("/builder/\(builderId)/projects/\(project.id)/documents")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    private func upload(_ url: URL, docType: String) async {
        guard let builderId = project.builderId ?? auth.builderId else { return }
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
                "/builder/\(builderId)/projects/\(project.id)/documents",
                fileData: data, fileName: url.lastPathComponent, mimeType: mime,
                fields: ["docType": docType]
            )
            message = "\(docType) uploaded"
            await load()
        } catch { message = authMessage(error) }
    }

    private func icon(_ docType: String?) -> String {
        switch (docType ?? "").lowercased() {
        case let t where t.contains("floor") || t.contains("tower") || t.contains("plan"): return "square.grid.3x3"
        case let t where t.contains("photo") || t.contains("image"): return "photo"
        case let t where t.contains("rera") || t.contains("approval"): return "checkmark.seal"
        case let t where t.contains("price"): return "indianrupeesign.circle"
        default: return "doc.text"
        }
    }
}
