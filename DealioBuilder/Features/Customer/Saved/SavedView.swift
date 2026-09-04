import SwiftUI

/// What a buyer has kept.
///
/// Two different things, kept apart because they mean different things: units
/// they *told a builder* they were interested in — which the builder has to
/// answer — and whole projects bookmarked privately, which nobody was told
/// about. Mirrors Android's `ui/customer/saved/SavedScreen.kt`.

@MainActor
final class SavedModel: ObservableObject {
    @Published var shortlists: [Shortlist] = []
    @Published var projects: [Project] = []
    @Published var loading = true
    @Published var error: String?
    @Published var message: String?

    var isEmpty: Bool { shortlists.isEmpty && projects.isEmpty }

    func load(phone: String, silent: Bool = false) async {
        if !silent { loading = isEmpty; error = nil }
        do {
            shortlists = try await APIClient.shared.get(
                APIClient.query("/portal/customer/shortlist", ["phone": phone])
            )
        } catch { self.error = authMessage(error) }
        projects = (try? await CustomerService.savedProjects()) ?? projects
        loading = false
    }

    /// Removes a bookmark from here — the same toggle as the one on the card.
    func unsave(_ projectId: Int) async {
        let previous = projects
        projects.removeAll { $0.id == projectId }
        do {
            try await CustomerService.unsaveProject(projectId)
            message = "Removed from saved"
        } catch {
            projects = previous
            message = authMessage(error)
        }
    }

    /// Asks the builder for a price on a unit already shortlisted. The unit id is
    /// what the request travels on, which is why the shortlist had to name a real
    /// flat rather than a configuration.
    func requestPricing(_ shortlist: Shortlist, phone: String) async {
        guard let builderId = shortlist.builderId else {
            message = "This project has no builder attached yet."
            return
        }
        var details: [String: String] = ["unit": shortlist.unitId]
        if let bhk = shortlist.unitDetails?.bhkType { details["bhkType"] = bhk }
        do {
            try await CustomerService.requestPricing(.init(
                builderId: builderId, projectId: shortlist.projectId, customerPhone: phone,
                unitId: shortlist.unitId, unitDetails: details,
                note: "Please share pricing for Unit \(shortlist.unitId)"
            ))
            message = "Pricing request sent."
        } catch { message = authMessage(error) }
    }
}

struct SavedView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = SavedModel()

    var body: some View {
        NavigationStack(path: router.path(3)) {
            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.error, model.isEmpty {
                    VStack(spacing: 14) {
                        ErrorBanner(message: error)
                        Button("Try again") { Task { await model.load(phone: auth.phone) } }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                } else if model.isEmpty {
                    ContentUnavailableView("Nothing saved yet", systemImage: "bookmark",
                        description: Text("Bookmark a project, or shortlist a unit you like, and it appears here."))
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if !model.shortlists.isEmpty {
                                SectionLabel("Units you asked about")
                                ForEach(model.shortlists) { shortlist in
                                    shortlistCard(shortlist)
                                }
                            }
                            if !model.projects.isEmpty {
                                SectionLabel("Projects you bookmarked").padding(.top, 6)
                                ForEach(model.projects) { project in
                                    NavigationLink(value: PortalRoute.customerProjectDetail(project.id)) {
                                        bookmarkCard(project)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await model.load(phone: auth.phone) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.customerSurface.ignoresSafeArea())
            .portalDestinations()
            .navigationTitle("Saved")
            .task { await model.load(phone: auth.phone) }
            .alert("Saved", isPresented: Binding(get: { model.message != nil },
                                                 set: { if !$0 { model.message = nil } })) {
                Button("OK", role: .cancel) { model.message = nil }
            } message: { Text(model.message ?? "") }
        }
    }

    private func shortlistCard(_ shortlist: Shortlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortlist.projectName?.nilIfEmpty ?? "Saved unit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text([shortlist.unitId.nilIfEmpty.map { "Unit \($0)" },
                          shortlist.unitDetails?.bhkType,
                          shortlist.unitDetails?.floor.map { "Floor \($0)" }]
                            .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                }
                Spacer()
                StatusBadge(text: shortlist.status, color: statusColor(shortlist.status))
            }
            if let note = shortlist.builderNote?.trimmedOrNil {
                Text("Builder: \(note)")
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let price = shortlist.unitDetails?.price?.nilIfEmpty {
                Text(price).font(.footnote.weight(.semibold)).foregroundStyle(Color.customerAccent)
            } else {
                Button { Task { await model.requestPricing(shortlist, phone: auth.phone) } } label: {
                    Label("Ask for a price", systemImage: "indianrupeesign.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.customerAccent)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.customerAccent.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func bookmarkCard(_ project: Project) -> some View {
        HStack(spacing: 12) {
            if let url = project.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.dealioFieldFill)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedCornerShape12())
            } else {
                IconBadge(systemImage: "building.2.fill", tint: .customerAccent, size: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)
                Text([project.locality, project.city].compactMap { $0?.nilIfEmpty }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary).lineLimit(1)
                if (project.priceMin ?? 0) > 0 {
                    Text("\(Money.inr(project.priceMin))+")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.customerAccent)
                }
            }
            Spacer()
            Button { Task { await model.unsave(project.id) } } label: {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.customerAccent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
