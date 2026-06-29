import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var projects: [Project] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading && projects.isEmpty {
                    LoadingList(rows: 4) { ProjectRow.placeholder }
                } else if let errorMessage, projects.isEmpty {
                    ScrollView { ErrorBanner(message: errorMessage).padding() }
                } else if projects.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "building.2",
                        description: Text("Projects you add on the web appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(projects) { project in
                                NavigationLink(value: project) {
                                    ProjectRow(project: project)
                                        .padding(12)
                                        .cardSurface()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .navigationDestination(for: Project.self) { ProjectDetailView(project: $0) }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Projects")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        if auth.builderId == nil { try? await auth.ensureBuilder() }
        guard let id = auth.builderId else { loading = false; return }
        do {
            projects = try await APIClient.shared.get("/builder/\(id)/projects")
        } catch let error {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
            VStack(alignment: .leading, spacing: 5) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                if let location = [project.locality, project.city].compactMap({ $0 }).first {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    if let status = project.status {
                        StatusBadge(text: status, color: statusColor(status))
                    }
                    Text(priceText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private var priceText: String {
        switch (project.priceMin, project.priceMax) {
        case let (min?, max?): return "\(Money.inr(min)) – \(Money.inr(max))"
        case let (min?, nil): return Money.inr(min)
        case let (nil, max?): return Money.inr(max)
        default: return "Price on request"
        }
    }

    @ViewBuilder private var thumbnail: some View {
        AsyncImage(url: project.imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    tintGradient(.brandTeal).opacity(0.18)
                    Image(systemName: "building.2.fill")
                        .font(.title3)
                        .foregroundStyle(.brandTeal)
                }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Redacted placeholder used while loading.
    static var placeholder: some View {
        ProjectRow(project: Project(
            id: Int.random(in: 1...9999),
            name: "Placeholder Project",
            city: "City",
            locality: "Locality",
            status: "Status",
            projectType: nil,
            totalUnits: nil,
            availableUnits: nil,
            soldUnits: nil,
            bookedUnits: nil,
            priceMin: 5_000_000,
            priceMax: 9_000_000,
            imageUrl: nil,
            possessionDate: nil,
            reraNumber: nil,
            published: nil
        ))
    }
}
