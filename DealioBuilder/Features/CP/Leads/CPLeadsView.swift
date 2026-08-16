import SwiftUI

@MainActor
final class CPLeadsModel: ObservableObject {
    @Published var leads: [CpLead] = []
    @Published var projects: [Project] = []
    @Published var loading = true
    @Published var error: String?
    @Published var working = false

    func load(cpUserId: Int) async {
        loading = leads.isEmpty
        error = nil
        do {
            leads = try await APIClient.shared.get("/cp/\(cpUserId)/leads")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    /// The projects a partner may refer into, for the new-lead picker.
    func loadProjects() async {
        guard projects.isEmpty else { return }
        projects = (try? await APIClient.shared.get("/builder/projects")) ?? []
    }

    func create(cpUserId: Int, projectId: Int, name: String, phone: String, email: String?) async {
        working = true
        defer { working = false }
        do {
            try await APIClient.shared.call(
                "/cp/\(cpUserId)/leads",
                body: CreateCpLeadRequest(projectId: projectId, customerName: name,
                                          customerPhone: phone, customerEmail: email)
            )
        } catch {
            self.error = authMessage(error)
        }
        await load(cpUserId: cpUserId)
    }
}

/// Which side of the conversion line a row is on.
///
/// `/cp/:id/leads` returns both, and counting all of them as leads *and* as
/// deals is what made the two tiles on the home screen disagree with each other.
/// The line is Negotiation — the point money enters the conversation.
enum CpLeadSide: String, CaseIterable, Identifiable {
    case leads = "Leads"
    case deals = "Deals"
    var id: String { rawValue }
}

struct CPLeadsView: View {
    /// Which side to open on. The home screen's Deals tile lands on Deals.
    var initialSide: CpLeadSide = .leads

    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPLeadsModel()
    @State private var query = ""
    @State private var side: CpLeadSide?
    @State private var adding = false

    private var cpUserId: Int { auth.user?.id ?? 0 }
    private var activeSide: CpLeadSide { side ?? initialSide }

    private var sideFiltered: [CpLead] {
        model.leads.filter {
            activeSide == .leads ? isLeadStage($0.status) : isDealStage($0.status)
        }
    }

    private var filtered: [CpLead] {
        guard !query.isEmpty else { return sideFiltered }
        return sideFiltered.filter {
            ($0.customerName ?? "").localizedCaseInsensitiveContains(query) ||
            ($0.projectName ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: Binding(get: { activeSide }, set: { side = $0 })) {
                    ForEach(CpLeadSide.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

                Group {
                    if model.loading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = model.error {
                        ErrorBanner(message: error).padding()
                    } else if filtered.isEmpty {
                        ContentUnavailableView(
                            activeSide == .leads ? "No leads yet" : "No deals yet",
                            systemImage: "person.2",
                            description: Text(activeSide == .leads
                                ? "Refer a customer from a project to start a lead."
                                : "A lead becomes a deal once pricing is on the table.")
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(filtered) { lead in
                                    NavigationLink {
                                        CPDealDetailView(dealId: lead.id, title: lead.customerName ?? "Lead")
                                    } label: { CpLeadRow(lead: lead) }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                        .searchable(text: $query, prompt: "Search \(activeSide.rawValue.lowercased())")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Leads")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) {
                NewLeadFormView(projects: model.projects) { projectId, name, phone, email in
                    Task { await model.create(cpUserId: cpUserId, projectId: projectId,
                                              name: name, phone: phone, email: email) }
                }
            }
            .task {
                await model.load(cpUserId: cpUserId)
                await model.loadProjects()
            }
            .refreshable { await model.load(cpUserId: cpUserId) }
        }
    }
}

/// Refers a buyer into a project. The project is the one thing that cannot be
/// filled in later — the lead belongs to whichever builder owns it.
struct NewLeadFormView: View {
    let projects: [Project]
    let onSave: (_ projectId: Int, _ name: String, _ phone: String, _ email: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var projectId: Int?
    @State private var name = ""
    @State private var countryCode = DEFAULT_DIAL_CODE
    @State private var phone = ""
    @State private var email = ""

    private var canSave: Bool {
        projectId != nil
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && phone.filter(\.isNumber).count >= 6
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    if projects.isEmpty {
                        Text("No projects available to refer into yet.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Picker("Project", selection: $projectId) {
                            Text("Choose a project").tag(Int?.none)
                            ForEach(projects) { project in
                                Text(project.name).tag(Int?.some(project.id))
                            }
                        }
                    }
                }
                Section("Buyer") {
                    TextField("Full name", text: $name).textContentType(.name)
                    ContactPhoneRow(countryCode: $countryCode, phone: $phone)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Refer a buyer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Refer") {
                        if let projectId {
                            onSave(projectId,
                                   name.trimmingCharacters(in: .whitespaces),
                                   dialable(countryCode, phone),
                                   email.nilIfBlank)
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
        }
    }
}
