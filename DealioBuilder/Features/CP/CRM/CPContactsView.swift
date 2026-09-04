import SwiftUI
import Contacts
import UniformTypeIdentifiers

/// The partner's contact book.
///
/// A CP reads this list to decide who to ring next, so a card leads with who the
/// person is and what they can spend, and puts call and WhatsApp on the card —
/// the number used to be something you read off and re-typed. Mirrors Android's
/// `ui/cp/contacts/ContactsScreen.kt`.

/// How the book is ordered. Newest first day to day; by spend when a project launches.
enum ContactSort: String, CaseIterable { case recent = "Recent", investment = "Top investors" }

/// A row parsed out of the phone book or a spreadsheet, waiting to be reviewed.
struct StagedContact: Identifiable {
    let id = UUID()
    var name: String
    var phone: String
    var countryCode: String = "+91"
    var email: String?
    var designation: String?
    var salary: Double?
    var investment: Double?
    var address: String?
    var selected: Bool

    var payload: CpContactPayload {
        CpContactPayload(name: name, phone: phone, countryCode: countryCode, email: email,
                         notes: nil, tags: nil, bhkPreference: nil,
                         designation: designation, salary: salary,
                         investment: investment, address: address)
    }
}

@MainActor
final class CPContactsModel: ObservableObject {
    @Published var items: [CpContact] = []
    @Published var loading = true
    @Published var error: String?
    @Published var message: String?
    @Published var sort: ContactSort = .recent

    // Rows waiting to be reviewed before import. Held here rather than in the
    // view so a redraw mid-review doesn't discard a parsed sheet.
    @Published var staged: [StagedContact]?
    @Published var stagedTitle = ""
    @Published var importing = false
    @Published var importProgress = 0

    private var cpUserId = 0

    /// Nobody with an unknown capacity outranks someone with a known one, so
    /// unset investments sink to the bottom rather than sorting as zero.
    var ordered: [CpContact] {
        switch sort {
        case .recent: return items
        case .investment: return items.sorted { ($0.investment ?? -1) > ($1.investment ?? -1) }
        }
    }

    func load(cpUserId: Int, silent: Bool = false) async {
        self.cpUserId = cpUserId
        if !silent { loading = items.isEmpty; error = nil }
        do { items = try await CPService.contacts(cpUserId: cpUserId) }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func save(existing: CpContact?, _ payload: CpContactPayload) async {
        do {
            if let existing {
                try await CPService.updateContact(cpUserId: cpUserId, contactId: existing.id, payload)
            } else {
                _ = try await CPService.createContact(cpUserId: cpUserId, payload)
            }
            message = "Saved"
            await load(cpUserId: cpUserId, silent: true)
        } catch { message = authMessage(error) }
    }

    func delete(_ contact: CpContact) async {
        do {
            try await CPService.deleteContact(cpUserId: cpUserId, contactId: contact.id)
            message = "Contact deleted"
            await load(cpUserId: cpUserId, silent: true)
        } catch { message = authMessage(error) }
    }

    // MARK: Bulk import

    /// Reads the device address book. Everyone starts unticked — a 500-contact
    /// phone book should not default to importing all of it.
    func stageFromPhone() async {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else {
            message = "Dealio needs access to Contacts to import them."
            return
        }
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]
        var rows: [StagedContact] = []
        let request = CNContactFetchRequest(keysToFetch: keys)
        try? store.enumerateContacts(with: request) { contact, _ in
            guard let number = contact.phoneNumbers.first?.value.stringValue else { return }
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }.joined(separator: " ")
            guard !name.isEmpty else { return }
            let (code, local) = Self.splitDialCode(number)
            rows.append(StagedContact(
                name: name, phone: local, countryCode: code,
                email: contact.emailAddresses.first.map { $0.value as String },
                designation: contact.jobTitle.nilIfEmpty ?? contact.organizationName.nilIfEmpty,
                selected: false
            ))
        }
        staged = rows.sorted { $0.name < $1.name }
        stagedTitle = "Import from phone"
    }

    /// Parses a picked spreadsheet — .xlsx or a delimited text export. The first
    /// row is treated as a header when it names the columns; otherwise the file
    /// is read as name, phone, email.
    func stageFromFile(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            message = "Could not read that file. An Excel or CSV export works best."
            return
        }
        staged = Self.rowsToContacts(Spreadsheet.read(data, fileName: url.lastPathComponent))
        stagedTitle = "Import from file"
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

    /// There is no bulk endpoint, so this is one POST per row. Failures are
    /// counted rather than aborting — one bad number shouldn't strand the rest.
    func importStaged() async {
        let chosen = (staged ?? []).filter(\.selected)
        guard !chosen.isEmpty else { return }
        importing = true
        importProgress = 0
        var saved = 0
        for (index, row) in chosen.enumerated() {
            if (try? await CPService.createContact(cpUserId: cpUserId, row.payload)) != nil { saved += 1 }
            importProgress = index + 1
        }
        importing = false
        staged = nil
        importProgress = 0
        let failed = chosen.count - saved
        message = failed == 0
            ? "Imported \(saved) contact\(saved == 1 ? "" : "s")."
            : "Imported \(saved) of \(chosen.count) — \(failed) could not be saved."
        await load(cpUserId: cpUserId, silent: true)
    }

    // MARK: Parsing helpers

    /// Splits "+44 7700 900123" into ("+44", "7700900123"). An unprefixed number
    /// is assumed Indian, which is what the payload defaults to anyway.
    static func splitDialCode(_ raw: String) -> (String, String) {
        let digits = raw.filter { $0.isNumber }
        guard raw.hasPrefix("+") else { return ("+91", String(digits.suffix(10))) }
        if digits.count > 10 {
            let local = String(digits.suffix(10))
            return ("+" + String(digits.dropLast(10)), local)
        }
        return ("+91", digits)
    }

    /// Turns parsed spreadsheet rows into stageable contacts.
    ///
    /// Works out which column is which from a header row, falling back to the
    /// conventional name, phone, email order when there isn't one.
    static func rowsToContacts(_ rows: [[String]]) -> [StagedContact] {
        var rows = rows
        guard !rows.isEmpty else { return [] }

        var nameIndex = 0, phoneIndex = 1, emailIndex = 2
        var designationIndex = -1, salaryIndex = -1, investmentIndex = -1, addressIndex = -1

        let header = rows[0].map { $0.lowercased() }
        let looksLikeHeader = header.contains { $0.contains("name") }
            && header.contains { $0.contains("phone") || $0.contains("mobile") }
        if looksLikeHeader {
            for (index, column) in header.enumerated() {
                if column.contains("name") { nameIndex = index }
                else if column.contains("phone") || column.contains("mobile") { phoneIndex = index }
                else if column.contains("email") { emailIndex = index }
                else if column.contains("designation") || column.contains("title") { designationIndex = index }
                else if column.contains("salary") || column.contains("income") { salaryIndex = index }
                else if column.contains("invest") || column.contains("budget") { investmentIndex = index }
                else if column.contains("address") || column.contains("city") { addressIndex = index }
            }
            rows.removeFirst()
        }

        func value(_ cells: [String], _ index: Int) -> String? {
            guard index >= 0, index < cells.count else { return nil }
            return cells[index].trimmedOrNil
        }
        func number(_ cells: [String], _ index: Int) -> Double? {
            value(cells, index).flatMap { Double($0.filter { $0.isNumber || $0 == "." }) }
        }

        return rows.compactMap { cells in
            guard let name = value(cells, nameIndex), let rawPhone = value(cells, phoneIndex) else { return nil }
            let (code, local) = splitDialCode(rawPhone)
            guard local.count >= 6 else { return nil }
            return StagedContact(
                name: name, phone: local, countryCode: code,
                email: value(cells, emailIndex),
                designation: value(cells, designationIndex),
                salary: number(cells, salaryIndex),
                investment: number(cells, investmentIndex),
                address: value(cells, addressIndex),
                selected: false
            )
        }
    }
}

// MARK: - Screen

struct CPContactsView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CPContactsModel()

    @State private var editing: CpContact?
    @State private var showEditor = false
    @State private var showChooser = false
    @State private var deleting: CpContact?
    @State private var showFileImporter = false
    @State private var query = ""

    private var filtered: [CpContact] {
        guard let needle = query.trimmedOrNil else { return model.ordered }
        return model.ordered.filter {
            $0.name.localizedCaseInsensitiveContains(needle) || $0.phone.contains(needle)
        }
    }

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
                ContentUnavailableView("No contacts yet", systemImage: "person.crop.circle",
                    description: Text("Tap Add to enter one, or import your phone book or a spreadsheet."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        sortRow
                        ForEach(filtered) { contact in
                            ContactCard(
                                contact: contact,
                                onEdit: { editing = contact; showEditor = true },
                                onDelete: { deleting = contact },
                                onCall: { if let url = Share.telURL(contact.dialable) { openURL(url) } },
                                onWhatsApp: {
                                    if let url = Share.whatsAppURL(phone: contact.phone,
                                                                   text: "Hi \(contact.name)!") { openURL(url) }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
                .searchable(text: $query, prompt: "Search contacts")
                .refreshable { await reload() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showChooser = true } label: { Label("Add", systemImage: "plus") }
            }
        }
        .task { await reload() }
        .confirmationDialog("Add contacts", isPresented: $showChooser, titleVisibility: .visible) {
            Button("Enter one by hand") { editing = nil; showEditor = true }
            Button("Import from phone") { Task { await model.stageFromPhone() } }
            Button("Import from Excel or CSV") { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        // Some providers report .csv under generic types, so accept plain text
        // too rather than greying out the user's own file.
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
        .sheet(isPresented: $showEditor) {
            ContactEditorSheet(existing: editing) { payload in
                let target = editing
                showEditor = false
                Task { await model.save(existing: target, payload) }
            }
        }
        .sheet(isPresented: Binding(get: { model.staged != nil },
                                    set: { if !$0 { model.clearStaged() } })) {
            ImportPreviewSheet(
                title: model.stagedTitle,
                rows: model.staged ?? [],
                working: model.importing,
                progress: model.importProgress,
                onToggle: { model.toggleStaged($0) },
                onSelectAll: { model.selectAllStaged($0) },
                onConfirm: { Task { await model.importStaged() } },
                onCancel: { model.clearStaged() }
            )
        }
        // Delete sits in the same action row as Call, so a mis-tap is a plausible
        // way to lose a contact the CP spent months collecting. Ask first.
        .alert("Delete contact?", isPresented: Binding(get: { deleting != nil },
                                                       set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) {
                if let target = deleting { Task { await model.delete(target) } }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("\(deleting?.name ?? "This contact") will be removed from your book.")
        }
        .alert("Contacts", isPresented: Binding(get: { model.message != nil },
                                                set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func reload() async {
        await model.load(cpUserId: auth.user?.id ?? 0)
    }

    private var sortRow: some View {
        HStack(spacing: 8) {
            ForEach(ContactSort.allCases, id: \.self) { option in
                let selected = model.sort == option
                Button { withAnimation(.snappy) { model.sort = option } } label: {
                    Text(option.rawValue)
                        .font(.caption.weight(selected ? .bold : .medium))
                        .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selected ? Color.brandTeal : Color(.secondarySystemGroupedBackground),
                                    in: Capsule())
                        .overlay(Capsule().strokeBorder(selected ? Color.brandTeal : Color.dealioCardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(model.items.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dealioTextSecondary)
        }
    }
}

// Accents rotate by name so a long book is scannable by colour as well as by
// text — two Rameshes still land on different tiles.
private let contactAccents: [Color] = [.brandTeal, .blue, .purple, .orange, .green]

private func accentFor(_ name: String) -> Color {
    let sum = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
    return contactAccents[sum % contactAccents.count]
}

private struct ContactCard: View {
    let contact: CpContact
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCall: () -> Void
    let onWhatsApp: () -> Void

    var body: some View {
        let accent = accentFor(contact.name)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                InitialsAvatar(name: contact.name, tint: accent, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name.nilIfEmpty ?? "Contact")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text(contact.dialable.nilIfEmpty ?? "—")
                        .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                    if let investment = contact.investment, investment > 0 {
                        Text("Can invest \(Money.inr(investment))/yr")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                    }
                }
                Spacer()
                Menu {
                    Button("Edit", systemImage: "pencil", action: onEdit)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Color.dealioTextSecondary)
                        .frame(width: 28, height: 28)
                }
            }

            // Qualifiers as chips that wrap, rather than a dot-joined line that
            // truncates the moment there are three of them.
            let chips = [contact.designation, contact.bhkPreference, contact.tags,
                         contact.email, contact.address].compactMap { $0?.trimmedOrNil }
            if !chips.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption2)
                            .foregroundStyle(Color.dealioTextSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.dealioFieldFill, in: Capsule())
                    }
                }
            }

            if let notes = contact.notes?.trimmedOrNil {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                actionChip("Call", "phone.fill", .brandTeal, onCall)
                actionChip("WhatsApp", "message.fill", .green, onWhatsApp)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func actionChip(_ title: String, _ icon: String, _ tint: Color,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editor

private struct ContactEditorSheet: View {
    let existing: CpContact?
    let onSave: (CpContactPayload) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var countryCode = "+91"
    @State private var phone = ""
    @State private var email = ""
    @State private var designation = ""
    @State private var bhk = ""
    @State private var tags = ""
    @State private var salary = ""
    @State private var investment = ""
    @State private var address = ""
    @State private var notes = ""

    private var canSave: Bool {
        name.trimmedOrNil != nil && phone.filter(\.isNumber).count >= 6
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who they are") {
                    TextField("Full name", text: $name).textContentType(.name)
                    HStack {
                        TextField("+91", text: $countryCode).frame(width: 64)
                        Divider()
                        TextField("Phone", text: $phone).keyboardType(.phonePad)
                    }
                    TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField("Designation", text: $designation)
                }
                Section("What they're after") {
                    TextField("BHK preference", text: $bhk)
                    TextField("Tags (comma separated)", text: $tags)
                    TextField("Annual salary (₹)", text: $salary).keyboardType(.numberPad)
                    TextField("Can invest per year (₹)", text: $investment).keyboardType(.numberPad)
                    TextField("Address / city", text: $address)
                }
                Section("Notes") {
                    TextField("Anything worth remembering", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle(existing == nil ? "New contact" : "Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(payload) }.disabled(!canSave)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private var payload: CpContactPayload {
        CpContactPayload(
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone.filter { $0.isNumber },
            countryCode: countryCode.trimmedOrNil ?? "+91",
            email: email.trimmedOrNil,
            notes: notes.trimmedOrNil,
            tags: tags.trimmedOrNil,
            bhkPreference: bhk.trimmedOrNil,
            designation: designation.trimmedOrNil,
            salary: Double(salary.filter(\.isNumber)),
            investment: Double(investment.filter(\.isNumber)),
            address: address.trimmedOrNil
        )
    }

    private func prefill() {
        guard let existing else { return }
        name = existing.name
        countryCode = existing.countryCode ?? "+91"
        phone = existing.phone
        email = existing.email ?? ""
        designation = existing.designation ?? ""
        bhk = existing.bhkPreference ?? ""
        tags = existing.tags ?? ""
        salary = existing.salary.map { String(Int($0)) } ?? ""
        investment = existing.investment.map { String(Int($0)) } ?? ""
        address = existing.address ?? ""
        notes = existing.notes ?? ""
    }
}

// MARK: - Import preview

private struct ImportPreviewSheet: View {
    let title: String
    let rows: [StagedContact]
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
                    HStack {
                        Button(chosen == rows.count ? "Deselect all" : "Select all") {
                            onSelectAll(chosen != rows.count)
                        }
                        .font(.footnote.weight(.semibold))
                        Spacer()
                        Text("\(chosen) of \(rows.count) selected")
                            .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)

                    List(rows) { row in
                        Button { onToggle(row.id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: row.selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(row.selected ? Color.brandTeal : Color.dealioTextSecondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.name).font(.subheadline.weight(.medium))
                                    Text(row.countryCode + row.phone)
                                        .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)

                    VStack(spacing: 8) {
                        if working {
                            ProgressView(value: Double(progress), total: Double(max(chosen, 1)))
                            Text("Importing \(progress) of \(chosen)…")
                                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                        }
                        Button(action: onConfirm) {
                            Text(chosen == 0 ? "Select someone to import" : "Import \(chosen) contact\(chosen == 1 ? "" : "s")")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(chosen == 0 || working ? Color.brandTeal.opacity(0.4) : Color.brandTeal,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(chosen == 0 || working)
                    }
                    .padding(16)
                }
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel).disabled(working)
                }
            }
        }
    }
}
