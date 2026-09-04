import SwiftUI

// MARK: - Model

/// A unit a buyer has asked the builder to hold — `builder/:id/shortlists`.
///
/// Richer than the buyer's own `Shortlist`: the builder needs to know who asked,
/// what they picked and what has already been said back.
struct BuilderShortlist: Codable, Identifiable {
    let id: Int
    var unitId: String = ""
    var unitDetails: ShortlistUnitDetails?
    var status: String = "Pending"
    var builderNote: String?
    var createdAt: String = ""
    var customerName: String = ""
    var customerPhone: String = ""
    var projectName: String = ""
    var projectCity: String = ""

    var isPending: Bool { status.caseInsensitiveCompare("Pending") == .orderedSame }

    private enum CodingKeys: String, CodingKey {
        case id, unitId, unitDetails, status, builderNote, createdAt
        case customerName, customerPhone, projectName, projectCity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        unitId = try c.decodeIfPresent(String.self, forKey: .unitId) ?? ""
        unitDetails = try c.decodeIfPresent(ShortlistUnitDetails.self, forKey: .unitDetails)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "Pending"
        builderNote = try c.decodeIfPresent(String.self, forKey: .builderNote)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        customerPhone = try c.decodeIfPresent(String.self, forKey: .customerPhone) ?? ""
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? ""
        projectCity = try c.decodeIfPresent(String.self, forKey: .projectCity) ?? ""
    }
}

struct ShortlistUnitDetails: Codable {
    var unitNumber: String?
    var tower: String?
    var floor: String?
    var bhkType: String?
    var carpetArea: String?
    var price: String?
    var facing: String?
    var status: String?
}

private struct ShortlistResponseRequest: Encodable {
    let status: String
    let builderNote: String?
}

@MainActor
final class BuilderShortlistsModel: ObservableObject {
    @Published var items: [BuilderShortlist] = []
    @Published var loading = true
    @Published var working = false
    @Published var error: String?

    func load(builderId: Int) async {
        loading = items.isEmpty
        error = nil
        do { items = try await APIClient.shared.get("/builder/\(builderId)/shortlists") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func respond(builderId: Int, shortlist: BuilderShortlist, status: String, note: String?) async {
        working = true
        defer { working = false }
        do {
            try await APIClient.shared.patchVoid(
                "/builder/\(builderId)/shortlists/\(shortlist.id)",
                body: ShortlistResponseRequest(status: status, builderNote: note)
            )
        } catch { self.error = authMessage(error) }
        await load(builderId: builderId)
    }
}

// MARK: - Screen

/// Units buyers have shortlisted, waiting on the builder's answer.
///
/// Mirrors Android's `ui/builder/shortlists/ShortlistsScreen.kt`: a pending row
/// opens a sheet with the two answers the backend accepts — accept the unit, or
/// suggest an alternative with a note.
struct BuilderShortlistsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderShortlistsModel()
    @State private var responding: BuilderShortlist?

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.items.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else if model.items.isEmpty {
                ContentUnavailableView("No shortlists", systemImage: "heart",
                    description: Text("Units customers shortlist appear here for your response."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.items) { item in
                            Button {
                                if item.isPending { responding = item }
                            } label: {
                                card(item)
                            }
                            .buttonStyle(.plain)
                            .disabled(!item.isPending)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await reload() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Shortlists")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(item: $responding) { shortlist in
            RespondSheet(shortlist: shortlist, working: model.working) { status, note in
                responding = nil
                Task {
                    if let id = await auth.resolvedBuilderId() {
                        await model.respond(builderId: id, shortlist: shortlist, status: status, note: note)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func reload() async {
        if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) }
    }

    private func card(_ item: BuilderShortlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.customerName.nilIfEmpty ?? "Customer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text(item.projectName.nilIfEmpty ?? "—")
                        .font(.caption)
                        .foregroundStyle(Color.dealioTextSecondary)
                }
                Spacer()
                StatusBadge(text: item.status, color: statusColor(item.status))
            }

            infoRow("Unit", item.unitDetails?.unitNumber ?? item.unitId)
            infoRow("Type", item.unitDetails?.bhkType)
            infoRow("Floor", item.unitDetails?.floor)
            infoRow("Price", item.unitDetails?.price)
            if let note = item.builderNote, !note.isEmpty { infoRow("Your note", note) }

            if item.isPending {
                Text("Tap to respond")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dealioStatusAmber)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                Spacer(minLength: 12)
                Text(value)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct RespondSheet: View {
    let shortlist: BuilderShortlist
    let working: Bool
    let onRespond: (String, String?) -> Void

    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Respond to \(shortlist.customerName.nilIfEmpty ?? "customer")")
                        .font(.title3.weight(.bold))
                    Text("\(shortlist.unitDetails?.unitNumber ?? shortlist.unitId) · \(shortlist.projectName)")
                        .font(.footnote)
                        .foregroundStyle(Color.dealioTextSecondary)
                }

                TextField("Optional note (for suggest alternative)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.dealioFieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
                    )

                Button {
                    onRespond("Accepted", note.trimmedOrNil)
                } label: {
                    Text("Accept unit")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.dealioStatusGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(working)

                Button {
                    onRespond("SuggestOther", note.trimmedOrNil ?? "Let me suggest a better-suited unit.")
                } label: {
                    Text("Suggest alternative")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.purple, lineWidth: 1)
                        )
                        .foregroundStyle(Color.purple)
                }
                .buttonStyle(.plain)
                .disabled(working)

                Spacer()
            }
            .padding(20)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
