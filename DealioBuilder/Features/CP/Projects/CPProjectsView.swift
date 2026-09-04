import SwiftUI

@MainActor
final class CPProjectsModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var loading = true
    @Published var error: String?

    func load() async {
        loading = projects.isEmpty
        error = nil
        do {
            projects = try await APIClient.shared.get("/builder/projects")
        } catch { self.error = authMessage(error) }
        loading = false
    }
}

struct CPProjectsView: View {
    @EnvironmentObject private var router: PortalRouter
    @StateObject private var model = CPProjectsModel()
    @State private var query = ""

    private var filtered: [Project] {
        query.isEmpty ? model.projects : model.projects.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            ($0.city ?? "").localizedCaseInsensitiveContains(query) ||
            ($0.locality ?? "").localizedCaseInsensitiveContains(query) ||
            ($0.builderName ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack(path: router.path(2)) {
            Group {
                if model.loading && model.projects.isEmpty {
                    ProgressView("Loading projects…")
                } else if let error = model.error, model.projects.isEmpty {
                    VStack(spacing: 14) {
                        ErrorBanner(message: error)
                        Button("Try again") { Task { await model.load() } }
                            .buttonStyle(.borderedProminent).tint(.brandTeal)
                    }
                    .padding()
                } else if model.projects.isEmpty {
                    ContentUnavailableView("No projects available",
                        systemImage: "building.2",
                        description: Text("Published projects you can refer will appear here."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filtered) { project in
                                NavigationLink(value: project) {
                                    CustomerProjectCard(project: project)
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $query, prompt: "Search projects, cities, builders")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dealioPageBackground()
            // Declared on the stack root rather than inside the populated branch,
            // so a refresh that briefly empties the list cannot unregister the
            // destination a push is relying on.
            .navigationDestination(for: Project.self) { CustomerProjectDetailView(project: $0, viewer: .cp) }
            .portalDestinations()
            .navigationTitle("Projects")
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }
}
