import SwiftUI

/// The shelf a bookmarked project is kept on.
///
/// This used to read `/portal/customer/shortlist`, which is a different thing
/// entirely — a shortlist is a *unit* put to the builder for a price. So a buyer
/// who had bookmarked five projects opened Saved and found either nothing or a
/// list of units they had asked to be quoted on.
struct SavedView: View {
    @EnvironmentObject private var saved: SavedProjectsStore

    var body: some View {
        NavigationStack {
            Group {
                if saved.loading {
                    ProgressView()
                } else if saved.projects.isEmpty {
                    ContentUnavailableView(
                        "Nothing saved yet",
                        systemImage: "bookmark",
                        description: Text("Tap the bookmark on a project to keep it here.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if let error = saved.error {
                                ErrorBanner(message: error).padding(.horizontal)
                            }
                            ForEach(saved.projects) { project in
                                NavigationLink(value: project) {
                                    CustomerProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Saved")
            .navigationDestination(for: Project.self) { CustomerProjectDetailView(project: $0) }
            .task { await saved.load() }
            .refreshable { await saved.load() }
        }
    }
}
