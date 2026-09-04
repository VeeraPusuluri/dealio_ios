import SwiftUI
import UniformTypeIdentifiers

/// The two sides of the lead/deal line.
///
/// The CP has a single `/cp/:id/leads` call that returns both — unlike the
/// builder, whose `/leads` and `/deals` the server partitions — so the split
/// happens here, on the same boundary the server uses.
enum LeadSide: String, CaseIterable { case leads = "Leads", deals = "Deals" }

@MainActor
final class CPLeadsModel: ObservableObject {
    @Published var all: [CpLead] = []
    @Published var side: LeadSide = .leads
    @Published var statusFilter = "All"
    @Published var loading = true
    @Published var error: String?
    @Published var working = false
    @Published var message: String?

    // Pickers for the add-lead form
    @Published var projects: [Project] = []
    @Published var contacts: [CpContact] = []

    // Bulk import staging — a lead needs a project, so the whole batch is filed
    // against one, chosen in the review sheet.
    @Published var staged: [StagedContact]?
    @Published var importProjectId: Int?
    @Published var importing = false
    @Published var importProgress = 0

    private var cpUserId = 0

    /// Still being worked — pre-Negotiation.
    var leads: [CpLead] { all.filter { DealFlow.isLeadStage($0.status) } }
    /// Money on the table — Negotiation onwards.
    var deals: [CpLead] { all.filter { DealFlow.isDealStage($0.status) } }
    /// The side currently on screen. Every list below reads from this, not `all`.
    var visible: [CpLead] { side == .leads ? leads : deals }

    /// Chips describe the visible side only — offering "Booked" while the Leads
    /// side is showing would filter to an empty screen the CP cannot explain.
    var statuses: [String] {
        var seen = Set<String>()
        return ["All"] + visible.compactMap { lead in
            let status = lead.status.nilIfEmpty ?? "—"
            return seen.insert(status).inserted ? status : nil
        }
    }

    var filtered: [CpLead] {
        statusFilter == "All" ? visible : visible.filter { $0.status == statusFilter }
    }

    func load(cpUserId: Int, silent: Bool = false) async {
        self.cpUserId = cpUserId
        if !silent { loading = all.isEmpty; error = nil }
        do { all = try await CPService.leads(cpUserId: cpUserId) }
        catch { self.error = authMessage(error) }
        loading = false
        // Pickers for the add-lead form (best-effort; failures leave them empty).
        projects = (try? await CPService.projects()) ?? projects
        contacts = onePerPerson((try? await CPService.contacts(cpUserId: cpUserId)) ?? contacts)
    }

    /// Switching sides clears the stage filter. The two sides share no stages, so
    /// carrying one over guarantees an empty list — "Negotiation" selected on the
    /// Leads side can never match.
    func setSide(_ newSide: LeadSide) {
        side = newSide
        statusFilter = "All"
    }

    func createLead(projectId: Int, name: String, phone: String, email: String?) async {
        working = true
        defer { working = false }
        do {
            try await CPService.createLead(cpUserId: cpUserId, .init(
                projectId: projectId, customerName: name, customerPhone: phone,
                customerEmail: email
            ))
            message = "Lead added for \(name)."
            await load(cpUserId: cpUserId, silent: true)
        } catch { message = authMessage(error) }
    }

    // MARK: Bulk import

    /// Same reader as the contact book — .xlsx or a delimited export. A lead
    /// needs a project, so the batch is filed against one chosen in the sheet.
    func stageFromFile(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            message = "Could not read that file. An Excel or CSV export works best."
            return
        }
        staged = CPContactsModel.rowsToContacts(Spreadsheet.read(data, fileName: url.lastPathComponent))
        importProjectId = projects.first?.id
        if staged?.isEmpty == true {
            message = "No usable rows found — the file needs a name and a phone column."
        }
    }

    func toggleStaged(_ id: UUID) {
        guard let index = staged?.firstIndex(where: { $0.id == id }) else { return }
        staged?[index].selected.toggle()
    }

    func selectAllStaged(_ select: Bool) {
        guard staged != nil else { return }
        for index in staged!.indices { staged![index].selected = select }
    }

    func clearStaged() { staged = nil; importProgress = 0 }

    /// One POST per row — there is no bulk endpoint. Failures are counted, not fatal.
    func importStaged() async {
        guard let projectId = importProjectId else { return }
        let chosen = (staged ?? []).filter(\.selected)
        guard !chosen.isEmpty else { return }
        importing = true
        importProgress = 0
        var saved = 0
        for (index, row) in chosen.enumerated() {
            let request = CPService.CreateLeadRequest(
                projectId: projectId, customerName: row.name,
                customerPhone: row.phone, customerEmail: row.email
            )
            if (try? await CPService.createLead(cpUserId: cpUserId, request)) != nil { saved += 1 }
            importProgress = index + 1
        }
        importing = false
        staged = nil
        importProgress = 0
        let failed = chosen.count - saved
        message = failed == 0
            ? "Imported \(saved) lead\(saved == 1 ? "" : "s")."
            : "Imported \(saved) of \(chosen.count) — \(failed) could not be saved."
        await load(cpUserId: cpUserId, silent: true)
    }
}

/// One chip per person for the add-lead form's contact shortcuts.
///
/// A book collects twins: importing the phone a second time re-adds everyone
/// already in it, and a buyer entered by hand turns up again in the next
/// spreadsheet. Harmless on the contacts page, where the CP can see and delete
/// the extra, but the picker is a single row where the same name twice is noise.
///
/// The newest row wins, being the one the CP last touched, and an older twin
/// lends whatever the newer one left blank rather than being dropped whole.
func onePerPerson(_ contacts: [CpContact]) -> [CpContact] {
    var byPerson: [String: CpContact] = [:]
    var order: [String] = []
    for contact in contacts {
        let digits = String((contact.countryCode ?? "").filter(\.isNumber) + contact.phone.filter(\.isNumber))
        // Contacts without a usable number are keyed by name, so two different
        // people missing one stay apart instead of collapsing into each other.
        let key = digits.count >= 6 ? digits : "name:" + contact.name.trimmingCharacters(in: .whitespaces).lowercased()
        if var kept = byPerson[key] {
            if kept.name.isEmpty { kept.name = contact.name }
            if kept.email?.nilIfEmpty == nil { kept.email = contact.email }
            byPerson[key] = kept
        } else {
            byPerson[key] = contact
            order.append(key)
        }
    }
    return order.compactMap { byPerson[$0] }
}

// MARK: - Screen

struct CPLeadsView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CPLeadsModel()

    @State private var adding = false
    @State private var showChooser = false
    @State private var showFileImporter = false
    @State private var openDeal: Int?

    var body: some View {
        NavigationStack(path: router.path(1)) {
            VStack(spacing: 0) {
                sidePicker
                if !model.visible.isEmpty { statusChips }

                Group {
                    if model.loading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = model.error, model.all.isEmpty {
                        VStack(spacing: 14) {
                            ErrorBanner(message: error)
                            Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                            Spacer()
                        }
                        .padding()
                    } else if model.filtered.isEmpty {
                        ContentUnavailableView(
                            model.side == .leads ? "No leads yet" : "No deals yet",
                            systemImage: model.side == .leads ? "person.2" : "indianrupeesign.circle",
                            description: Text(model.side == .leads
                                ? "Add a buyer against a project and they appear here."
                                : "A lead becomes a deal once pricing is on the table.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(model.filtered) { lead in
                                    Button { openDeal = lead.id } label: { card(lead) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable { await reload() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .portalDestinations()
            .navigationTitle("Pipeline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showChooser = true } label: { Label("Add", systemImage: "plus") }
                }
            }
            .navigationDestination(item: $openDeal) { id in
                CPDealDetailView(dealId: id)
            }
            .task { await reload() }
            .confirmationDialog("Add leads", isPresented: $showChooser, titleVisibility: .visible) {
                Button("Enter one by hand") { adding = true }
                Button("Import from Excel or CSV") { showFileImporter = true }
                Button("Cancel", role: .cancel) {}
            }
            // Some providers report .xlsx and .csv under generic types, so the
            // catch-all is there too rather than greying out the user's own file.
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [.spreadsheet, .commaSeparatedText,
                                                .plainText, .text, .data],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task { await model.stageFromFile(url) }
                }
            }
            .sheet(isPresented: $adding) {
                AddLeadSheet(projects: model.projects, contacts: model.contacts, working: model.working) {
                    projectId, name, phone, email in
                    adding = false
                    Task { await model.createLead(projectId: projectId, name: name, phone: phone, email: email) }
                }
            }
            .sheet(isPresented: Binding(get: { model.staged != nil },
                                        set: { if !$0 { model.clearStaged() } })) {
                LeadImportSheet(
                    rows: model.staged ?? [],
                    projects: model.projects,
                    projectId: $model.importProjectId,
                    working: model.importing,
                    progress: model.importProgress,
                    onToggle: { model.toggleStaged($0) },
                    onSelectAll: { model.selectAllStaged($0) },
                    onConfirm: { Task { await model.importStaged() } },
                    onCancel: { model.clearStaged() }
                )
            }
            .alert("Pipeline", isPresented: Binding(get: { model.message != nil },
                                                    set: { if !$0 { model.message = nil } })) {
                Button("OK", role: .cancel) { model.message = nil }
            } message: { Text(model.message ?? "") }
        }
    }

    private func reload() async { await model.load(cpUserId: auth.user?.id ?? 0) }

    private var sidePicker: some View {
        Picker("", selection: Binding(get: { model.side }, set: { model.setSide($0) })) {
            ForEach(LeadSide.allCases, id: \.self) { side in
                Text(side == .leads ? "Leads · \(model.leads.count)" : "Deals · \(model.deals.count)")
                    .tag(side)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    }

    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.statuses, id: \.self) { status in
                    let selected = model.statusFilter == status
                    Button { withAnimation(.snappy) { model.statusFilter = status } } label: {
                        Text(status)
                            .font(.caption.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selected ? Color.brandTeal : Color(.secondarySystemGroupedBackground),
                                        in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? Color.brandTeal : Color.dealioCardBorder,
                                                            lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
        }
    }

    private func card(_ lead: CpLead) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                InitialsAvatar(name: lead.customerName, tint: statusColor(lead.status), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.customerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text(lead.projectName).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                }
                Spacer()
                StatusBadge(text: lead.status.nilIfEmpty ?? "New", color: statusColor(lead.status))
            }

            // The baton, so a partner reads what they owe without opening the deal.
            let baton = DealFlow.baton(lead.status, cpAgreed: lead.cpAgreed,
                                       customerConfirmed: lead.customerConfirmed)
            if !baton.isComplete {
                Text(baton.heldBy(.cp) ? "Your move · \(baton.action)"
                                       : "Waiting on \(baton.holders.map(\.label).joined(separator: " and "))")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(baton.heldBy(.cp) ? Color.brandTeal : Color.dealioTextSecondary)
            }

            Divider()

            HStack {
                if let commission = lead.estimatedCommission, commission > 0 {
                    Label(Money.inr(commission), systemImage: "indianrupeesign.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                Spacer()
                if let value = lead.dealValue, value > 0 {
                    Text(Money.inr(value))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                }
                if !lead.customerPhone.isEmpty {
                    Button { if let url = Share.telURL(lead.customerPhone) { openURL(url) } } label: {
                        Image(systemName: "phone.fill").font(.caption).foregroundStyle(Color.brandTeal)
                            .frame(width: 28, height: 28)
                            .background(Color.brandTeal.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

// MARK: - Add lead

private struct AddLeadSheet: View {
    let projects: [Project]
    let contacts: [CpContact]
    let working: Bool
    let onCreate: (Int, String, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var projectId: Int?
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""

    private var canSave: Bool {
        projectId != nil && name.trimmedOrNil != nil && phone.filter(\.isNumber).count >= 6
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Which project") {
                    Picker("Project", selection: $projectId) {
                        Text("Choose a project").tag(Int?.none)
                        ForEach(projects) { project in
                            Text(project.name).tag(Int?.some(project.id))
                        }
                    }
                }
                Section("The buyer") {
                    TextField("Full name", text: $name).textContentType(.name)
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
                if !contacts.isEmpty {
                    Section("Or pick from your contacts") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(contacts) { contact in
                                    Button {
                                        name = contact.name
                                        phone = contact.phone
                                        email = contact.email ?? ""
                                    } label: {
                                        Text(contact.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(Color.dealioFieldFill, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
            .navigationTitle("Add a lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let projectId, let trimmed = name.trimmedOrNil else { return }
                        onCreate(projectId, trimmed, phone.filter(\.isNumber), email.trimmedOrNil)
                    }
                    .disabled(!canSave || working)
                }
            }
            .onAppear { if projectId == nil { projectId = projects.first?.id } }
        }
    }
}

// MARK: - Import

private struct LeadImportSheet: View {
    let rows: [StagedContact]
    let projects: [Project]
    @Binding var projectId: Int?
    let working: Bool
    let progress: Int
    let onToggle: (UUID) -> Void
    let onSelectAll: (Bool) -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var chosen: Int { rows.filter(\.selected).count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if rows.isEmpty {
                    ContentUnavailableView("Nothing to import", systemImage: "tray",
                        description: Text("No rows with both a name and a phone number were found."))
                } else {
                    Form {
                        Section("File them against") {
                            Picker("Project", selection: $projectId) {
                                Text("Choose a project").tag(Int?.none)
                                ForEach(projects) { project in
                                    Text(project.name).tag(Int?.some(project.id))
                                }
                            }
                        }
                        Section {
                            ForEach(rows) { row in
                                Button { onToggle(row.id) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: row.selected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(row.selected ? Color.brandTeal : Color.dealioTextSecondary)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(row.name).font(.subheadline)
                                            Text(row.countryCode + row.phone)
                                                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack {
                                Text("\(chosen) of \(rows.count) selected")
                                Spacer()
                                Button(chosen == rows.count ? "Deselect all" : "Select all") {
                                    onSelectAll(chosen != rows.count)
                                }
                                .font(.caption.weight(.semibold))
                            }
                        }
                    }

                    VStack(spacing: 8) {
                        if working {
                            ProgressView(value: Double(progress), total: Double(max(chosen, 1)))
                            Text("Importing \(progress) of \(chosen)…")
                                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                        }
                        Button(action: onConfirm) {
                            Text(projectId == nil ? "Pick a project first"
                                 : chosen == 0 ? "Select someone to import"
                                 : "Import \(chosen) lead\(chosen == 1 ? "" : "s")")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(canImport ? Color.brandTeal : Color.brandTeal.opacity(0.4),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canImport)
                    }
                    .padding(16)
                }
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Import leads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel).disabled(working)
                }
            }
        }
    }

    private var canImport: Bool { projectId != nil && chosen > 0 && !working }
}
