import SwiftUI

// MARK: - Contacts

@MainActor
final class CPContactsModel: ObservableObject {
    @Published var contacts: [CpContact] = []
    @Published var loading = true
    @Published var error: String?
    @Published var working = false

    func load(cpUserId: Int) async {
        loading = contacts.isEmpty
        error = nil
        do { contacts = try await APIClient.shared.get("/cp/\(cpUserId)/contacts") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    /// Creates or updates, depending on whether we already have an id for them.
    func save(cpUserId: Int, contactId: Int?, payload: CpContactPayload) async {
        working = true
        defer { working = false }
        do {
            if let contactId {
                try await APIClient.shared.call("/cp/\(cpUserId)/contacts/\(contactId)",
                                                method: "PATCH", body: payload)
            } else {
                try await APIClient.shared.call("/cp/\(cpUserId)/contacts", body: payload)
            }
        } catch {
            self.error = authMessage(error)
        }
        await load(cpUserId: cpUserId)
    }

    func delete(cpUserId: Int, contactId: Int) async {
        working = true
        defer { working = false }
        do {
            try await APIClient.shared.call("/cp/\(cpUserId)/contacts/\(contactId)", method: "DELETE")
        } catch {
            self.error = authMessage(error)
        }
        await load(cpUserId: cpUserId)
    }

    /// Contacts already in the book, by the identity the server matches on, so a
    /// second row for the same buyer can be spotted before it is created.
    var identities: Set<String> {
        Set(contacts.map { phoneIdentity($0.countryCode, $0.phone ?? "") })
    }
}

struct CPContactsView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CPContactsModel()
    @State private var editing: ContactEdit?

    private var cpUserId: Int { auth.user?.id ?? 0 }

    var body: some View {
        Group {
            if model.loading {
                ProgressView()
            } else if model.contacts.isEmpty {
                ContentUnavailableView {
                    Label("No contacts yet", systemImage: "person.crop.circle")
                } description: {
                    Text("Add buyers to your CRM to follow up and broadcast to them.")
                } actions: {
                    Button("Add a contact") { editing = ContactEdit() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    if let error = model.error {
                        Section { ErrorBanner(message: error) }
                    }
                    ForEach(model.contacts) { contact in
                        row(contact)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await model.delete(cpUserId: cpUserId, contactId: contact.id) }
                                } label: { Label("Delete", systemImage: "trash") }
                                Button {
                                    editing = ContactEdit(contact: contact)
                                } label: { Label("Edit", systemImage: "pencil") }
                                .tint(.brandTeal)
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = ContactEdit() } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { edit in
            ContactFormView(
                existing: edit.contact,
                knownIdentities: model.identities
            ) { payload in
                Task { await model.save(cpUserId: cpUserId, contactId: edit.contact?.id, payload: payload) }
            }
        }
        .task { await model.load(cpUserId: cpUserId) }
        .refreshable { await model.load(cpUserId: cpUserId) }
    }

    private func row(_ contact: CpContact) -> some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: contact.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name ?? "Contact").font(.subheadline.weight(.semibold))
                Text([formatPhone(contact.countryCode, contact.phone ?? ""), contact.bhkPreference]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let phone = contact.phone, !phone.isEmpty {
                let dial = dialable(contact.countryCode, phone)
                Button { if let u = Share.telURL(dial) { openURL(u) } } label: {
                    Image(systemName: "phone.fill")
                }
                .buttonStyle(.borderless)
                Button {
                    if let u = Share.whatsAppURL(phone: dial, text: "Hi \(contact.name ?? "")!") { openURL(u) }
                } label: {
                    Image(systemName: "message.fill")
                }
                .buttonStyle(.borderless).tint(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A contact being added (no `contact`) or edited.
private struct ContactEdit: Identifiable {
    var contact: CpContact? = nil
    var id: Int { contact?.id ?? 0 }
}

/// The add/edit form. Warns rather than blocks on a number already in the book —
/// a CP sometimes genuinely wants two rows, and refusing outright is worse than
/// telling them.
struct ContactFormView: View {
    let existing: CpContact?
    var knownIdentities: Set<String> = []
    let onSave: (CpContactPayload) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var countryCode = DEFAULT_DIAL_CODE
    @State private var phone = ""
    @State private var email = ""
    @State private var bhk = ""
    @State private var designation = ""
    @State private var notes = ""

    private var isDuplicate: Bool {
        guard existing == nil, phone.count >= 6 else { return false }
        return knownIdentities.contains(phoneIdentity(countryCode, phone))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && phone.filter(\.isNumber).count >= 6
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    TextField("Full name", text: $name).textContentType(.name)
                    ContactPhoneRow(countryCode: $countryCode, phone: $phone)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
                if isDuplicate {
                    Section {
                        Label("You already have a contact with this number.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section("What they're after") {
                    TextField("BHK preference, e.g. 3BHK", text: $bhk)
                    TextField("Designation", text: $designation)
                }
                Section("Notes") {
                    TextField("Anything worth remembering", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "New contact" : "Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(CpContactPayload(
                            name: name.trimmingCharacters(in: .whitespaces),
                            phone: phone.filter(\.isNumber),
                            countryCode: countryCode,
                            email: email.nilIfBlank,
                            notes: notes.nilIfBlank,
                            bhkPreference: bhk.nilIfBlank,
                            designation: designation.nilIfBlank,
                            salary: nil,
                            investment: nil,
                            address: nil
                        ))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: seed)
    }

    private func seed() {
        guard let existing else { return }
        name = existing.name ?? ""
        countryCode = existing.countryCode ?? DEFAULT_DIAL_CODE
        phone = existing.phone ?? ""
        email = existing.email ?? ""
        bhk = existing.bhkPreference ?? ""
        designation = existing.designation ?? ""
        notes = existing.notes ?? ""
    }
}

extension String {
    /// The trimmed string, or `nil` when there is nothing in it — so a blank
    /// field clears a column rather than writing an empty string into it.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Follow-ups

@MainActor
final class CPFollowUpsModel: ObservableObject {
    @Published var items: [CpFollowUp] = []
    @Published var loading = true
    @Published var error: String?

    func load(cpUserId: Int) async {
        loading = items.isEmpty
        error = nil
        do { items = try await APIClient.shared.get("/cp/\(cpUserId)/follow-ups") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func markDone(cpUserId: Int, id: String) async {
        do {
            try await APIClient.shared.call("/cp/\(cpUserId)/follow-ups/\(id)/done", method: "PATCH")
        } catch {
            self.error = authMessage(error)
        }
        await load(cpUserId: cpUserId)
    }

    func create(cpUserId: Int, dealId: Int, due: Date, reason: String) async {
        do {
            try await APIClient.shared.call(
                "/cp/\(cpUserId)/follow-ups",
                body: CreateFollowUpRequest(
                    dealId: dealId,
                    dueDate: MeetingAnswerSheet.dateFormatter.string(from: due),
                    dueTime: MeetingAnswerSheet.timeFormatter.string(from: due),
                    reason: reason
                )
            )
        } catch {
            self.error = authMessage(error)
        }
        await load(cpUserId: cpUserId)
    }
}

struct CPFollowUpsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPFollowUpsModel()

    private var cpUserId: Int { auth.user?.id ?? 0 }

    var body: some View {
        Group {
            if model.loading {
                ProgressView()
            } else if model.items.isEmpty {
                ContentUnavailableView("No follow-ups due", systemImage: "bell.badge",
                    description: Text("Scheduled follow-ups with your leads appear here."))
            } else {
                List {
                    if let error = model.error {
                        Section { ErrorBanner(message: error) }
                    }
                    ForEach(model.items) { item in
                        HStack(spacing: 12) {
                            IconBadge(systemImage: "bell.fill", tint: .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.customerName ?? "Lead").font(.subheadline.weight(.semibold))
                                Text(item.projectName ?? "—").font(.caption).foregroundStyle(.secondary)
                                if let reason = item.reason, !reason.isEmpty {
                                    Text(reason).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text([item.dueDate, item.dueTime].compactMap { $0 }.joined(separator: " "))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button {
                                Task { await model.markDone(cpUserId: cpUserId, id: item.id) }
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Follow-ups")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: cpUserId) }
        .refreshable { await model.load(cpUserId: cpUserId) }
    }
}

/// Schedules a follow-up against one deal. Presented from the deal room's
/// *Meeting Done* stage action, where logging one is the CP's next move.
struct FollowUpFormView: View {
    let customerName: String
    let onSave: (_ due: Date, _ reason: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var due = Date().addingTimeInterval(86_400)
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            Form {
                Section { LabeledContent("Lead", value: customerName) }
                Section("When") {
                    DatePicker("Due", selection: $due)
                }
                Section("What for") {
                    TextField("e.g. Send the payment plan for the 3BHK", text: $reason, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Log a follow-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        onSave(due, reason.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Meetings

struct CPMeetingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var meetings: [CpMeeting] = []
    @State private var loading = true
    @State private var error: String?
    @State private var mode: MeetingViewMode = .list

    private var calMeetings: [CalMeeting] {
        meetings.compactMap { m in
            CalMeeting(id: "\(m.id)", dateString: m.confirmedDate ?? m.preferredDate,
                       time: m.confirmedTime ?? m.preferredTime, title: m.customerName ?? "Visitor",
                       subtitle: nil, status: m.status, color: statusColor(m.status))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(MeetingViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            Group {
                if loading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if let error { ErrorBanner(message: error).padding() }
                else if mode == .calendar {
                    MeetingCalendarView(meetings: calMeetings)
                } else if meetings.isEmpty {
                    ContentUnavailableView("No meetings yet", systemImage: "calendar",
                        description: Text("Site visits you arrange for your leads appear here."))
                } else {
                    List(meetings) { m in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(m.customerName ?? "Visitor").font(.subheadline.weight(.semibold))
                                Spacer()
                                StatusBadge(text: m.status ?? "Pending", color: statusColor(m.status))
                            }
                            if !m.whenText.isEmpty {
                                Label(m.whenText, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Meetings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = meetings.isEmpty
        do { meetings = try await APIClient.shared.get("/cp/\(auth.user?.id ?? 0)/meetings") }
        catch { self.error = authMessage(error) }
        loading = false
    }
}
