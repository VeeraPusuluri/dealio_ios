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
    @StateObject private var model = CPProjectsModel()
    @State private var query = ""

    private var filtered: [Project] {
        query.isEmpty ? model.projects : model.projects.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            ($0.city ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.loading {
                    ProgressView()
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if model.projects.isEmpty {
                    ContentUnavailableView("No projects available",
                        systemImage: "building.2",
                        description: Text("Published projects you can refer will appear here."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filtered) { project in
                                NavigationLink(value: project) {
                                    CustomerProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $query, prompt: "Search projects")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Projects")
            .navigationDestination(for: Project.self) { CustomerProjectDetailView(project: $0) }
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }
}
