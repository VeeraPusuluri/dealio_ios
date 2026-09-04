import Foundation

/// Loaders shared by more than one screen.
///
/// A screen that needs the same list as another screen asks the same model for
/// it, rather than re-deriving the endpoint and the error handling — which is
/// how the two drifted apart on Android before `BuilderRepository` existed.

@MainActor
final class BuilderProjectsModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var loading = true
    @Published var error: String?

    func load(builderId: Int) async {
        loading = projects.isEmpty
        error = nil
        do { projects = try await APIClient.shared.get("/builder/\(builderId)/projects") }
        catch { self.error = authMessage(error) }
        loading = false
    }
}
