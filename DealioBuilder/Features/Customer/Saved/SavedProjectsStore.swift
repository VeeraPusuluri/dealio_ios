import SwiftUI

/// The buyer's bookmarks, held once for the whole portal.
///
/// A bookmark shows up in three places — the card in Explore, the button on the
/// project page, and the Saved shelf — and each of them has to agree instantly.
/// Held on the customer shell rather than in any one screen's model, so tapping
/// the bookmark on a card fills the star on the project page too.
///
/// Saved is not the same thing as shortlisted: a shortlist is a *unit* put to
/// the builder for an answer, which is why the Saved tab reading the shortlist
/// endpoint showed a buyer units they had asked to be priced rather than the
/// projects they had bookmarked.
@MainActor
final class SavedProjectsStore: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var loading = false
    @Published var error: String?

    /// Ids only, for the O(1) check every card does while scrolling.
    @Published private(set) var savedIds: Set<Int> = []

    /// Ids with a save/unsave in flight, so a card can show the new state at once
    /// and still be prevented from firing twice.
    @Published private(set) var pending: Set<Int> = []

    func isSaved(_ projectId: Int) -> Bool { savedIds.contains(projectId) }

    func load() async {
        loading = projects.isEmpty
        error = nil
        do {
            projects = try await APIClient.shared.get("/customer/saved-projects")
            savedIds = Set(projects.map(\.id))
        } catch {
            self.error = authMessage(error)
        }
        loading = false
    }

    /// Saves or unsaves, updating the shelf optimistically.
    ///
    /// The backend's save is idempotent — two taps, or the same account on two
    /// devices, must not become two rows — so a retry is harmless.
    func toggle(_ project: Project) async {
        let id = project.id
        guard !pending.contains(id) else { return }
        pending.insert(id)
        defer { pending.remove(id) }

        let wasSaved = savedIds.contains(id)
        if wasSaved {
            savedIds.remove(id)
            projects.removeAll { $0.id == id }
        } else {
            savedIds.insert(id)
            if !projects.contains(where: { $0.id == id }) { projects.insert(project, at: 0) }
        }

        do {
            try await APIClient.shared.call(
                "/customer/saved-projects/\(id)",
                method: wasSaved ? "DELETE" : "POST"
            )
        } catch {
            // Put it back the way it was — a bookmark that silently didn't
            // stick is worse than one that visibly refused.
            self.error = authMessage(error)
            if wasSaved {
                savedIds.insert(id)
                if !projects.contains(where: { $0.id == id }) { projects.insert(project, at: 0) }
            } else {
                savedIds.remove(id)
                projects.removeAll { $0.id == id }
            }
        }
    }
}

/// The bookmark itself. Sits on every project card and on the project page.
struct BookmarkButton: View {
    let project: Project
    var size: CGFloat = 32

    @EnvironmentObject private var saved: SavedProjectsStore

    var body: some View {
        Button {
            Task { await saved.toggle(project) }
        } label: {
            Image(systemName: saved.isSaved(project.id) ? "bookmark.fill" : "bookmark")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(saved.isSaved(project.id) ? Color.dealioOrange : .white)
                .frame(width: size, height: size)
                .background(.black.opacity(0.28), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saved.isSaved(project.id) ? "Remove bookmark" : "Bookmark this project")
    }
}
