import SwiftUI

struct BuilderRERAView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderProjectsListModel()

    private var registered: Int { model.projects.filter { !($0.reraNumber ?? "").isEmpty }.count }

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if model.projects.isEmpty {
                ContentUnavailableView("No projects", systemImage: "checkmark.seal",
                    description: Text("Add a project to track its RERA compliance."))
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            StatCard(title: "Projects", value: "\(model.projects.count)", systemImage: "building.2", tint: .brandTeal)
                            StatCard(title: "RERA-registered", value: "\(registered)", systemImage: "checkmark.seal", tint: .green)
                        }
                        VStack(spacing: 12) {
                            ForEach(model.projects) { p in
                                let ok = !(p.reraNumber ?? "").isEmpty
                                HStack(spacing: 12) {
                                    Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(ok ? .green : .orange).font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.name).font(.subheadline.weight(.semibold))
                                        Text(ok ? "RERA: \(p.reraNumber ?? "")" : "RERA number missing")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusBadge(text: ok ? "Registered" : "Pending", color: ok ? .green : .orange)
                                }
                                .padding(14).frame(maxWidth: .infinity).cardSurface()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("RERA Compliance")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
