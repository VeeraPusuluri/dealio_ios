import SwiftUI

@MainActor
final class SavedModel: ObservableObject {
    @Published var items: [Shortlist] = []
    @Published var loading = true
    @Published var error: String?

    func load(phone: String) async {
        loading = items.isEmpty
        error = nil
        do {
            items = try await APIClient.shared.get("/portal/customer/shortlist?phone=\(phone)")
        } catch { self.error = authMessage(error) }
        loading = false
    }
}

struct SavedView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = SavedModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.loading {
                    ProgressView()
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if model.items.isEmpty {
                    ContentUnavailableView("Nothing saved yet",
                        systemImage: "bookmark",
                        description: Text("Shortlist units you like to compare them here."))
                } else {
                    List(model.items) { item in
                        HStack(spacing: 12) {
                            IconBadge(systemImage: "bookmark.fill", tint: .dealioOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.projectName ?? "Saved unit").font(.subheadline.weight(.semibold))
                                if let unit = item.unitId, !unit.isEmpty {
                                    Text("Unit \(unit)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Saved")
            .task { await model.load(phone: auth.phone) }
            .refreshable { await model.load(phone: auth.phone) }
        }
    }
}
