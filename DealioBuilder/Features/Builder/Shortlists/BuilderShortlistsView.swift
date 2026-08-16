import SwiftUI

/// The units customers have shortlisted, and the builder's answer to each.
///
/// This is the stage-action destination at *Meeting Done* — the buyer has
/// visited and picked a unit, and accepting one is what moves the deal to
/// Negotiation, so it is a step the pipeline cannot skip.
@MainActor
final class BuilderShortlistsModel: ObservableObject {
    @Published var shortlists: [UnitShortlist] = []
    @Published var loading = true
    @Published var error: String?
    @Published var responding: Int?

    func load(builderId: Int) async {
        loading = shortlists.isEmpty
        error = nil
        do { shortlists = try await APIClient.shared.get("/builder/\(builderId)/shortlists") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func respond(builderId: Int, shortlistId: Int, status: String, note: String?) async {
        responding = shortlistId
        defer { responding = nil }
        do {
            try await APIClient.shared.call(
                "/builder/\(builderId)/shortlists/\(shortlistId)",
                method: "PATCH",
                body: ShortlistResponseRequest(status: status, builderNote: note)
            )
        } catch {
            self.error = authMessage(error)
        }
        await load(builderId: builderId)
    }
}

struct BuilderShortlistsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderShortlistsModel()
    @State private var suggesting: UnitShortlist?
    @State private var note = ""

    var body: some View {
        Group {
            if model.loading {
                ProgressView()
            } else if model.shortlists.isEmpty {
                ContentUnavailableView(
                    "No shortlists yet",
                    systemImage: "square.grid.2x2",
                    description: Text("When a buyer picks a unit after a site visit, it lands here for your answer.")
                )
            } else {
                List {
                    if let error = model.error {
                        Section { ErrorBanner(message: error) }
                    }
                    ForEach(model.shortlists) { shortlist in
                        Section { row(shortlist) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Shortlists")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .alert("Suggest another unit", isPresented: .constant(suggesting != nil)) {
            TextField("What would suit them better?", text: $note)
            Button("Cancel", role: .cancel) { suggesting = nil; note = "" }
            Button("Send") {
                let target = suggesting
                let text = note
                suggesting = nil
                note = ""
                Task {
                    guard let target, let id = await auth.resolvedBuilderId() else { return }
                    await model.respond(builderId: id, shortlistId: target.id,
                                        status: "SuggestOther",
                                        note: text.isEmpty ? nil : text)
                }
            }
        }
    }

    private func row(_ shortlist: UnitShortlist) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortlist.customerName ?? "Customer")
                        .font(.subheadline.weight(.semibold))
                    Text([shortlist.projectName, shortlist.unitId.map { "Unit \($0)" }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: shortlist.status ?? "Pending", color: statusColor(shortlist.status))
            }

            if let note = shortlist.builderNote, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }

            if shortlist.isPending {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            if let id = await auth.resolvedBuilderId() {
                                await model.respond(builderId: id, shortlistId: shortlist.id,
                                                    status: "Accepted", note: nil)
                            }
                        }
                    } label: {
                        Text("Accept")
                            .font(.footnote.weight(.bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(Color.dealioTeal, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        suggesting = shortlist
                    } label: {
                        Text("Suggest another")
                            .font(.footnote.weight(.bold)).foregroundStyle(Color.dealioTeal)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.dealioTeal.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .disabled(model.responding == shortlist.id)
                .opacity(model.responding == shortlist.id ? 0.5 : 1)
            }
        }
        .padding(.vertical, 4)
    }
}
