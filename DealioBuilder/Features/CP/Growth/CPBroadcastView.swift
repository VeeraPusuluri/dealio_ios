import SwiftUI

/// A personalised WhatsApp message to a chosen set of contacts.
///
/// Not a real broadcast — WhatsApp has no API for one from a phone. Each contact
/// gets their own chat opened with their own name already in the message, which
/// is both what the platform allows and what actually gets replies. Mirrors
/// Android's `ui/cp/growth/WhatsAppBroadcastScreen.kt`.

/// How many chats to open in one go.
///
/// iOS will not queue a stack of `openURL` calls: each one switches apps, and the
/// ones behind it are dropped. Three is what survives, and the copy says so
/// rather than pretending the other forty were sent.
private let broadcastBatch = 3

struct CPBroadcastView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CPGrowthModel()

    @State private var selectedContacts: Set<Int> = []
    @State private var projectId: Int?
    @State private var custom = ""
    @State private var message: String?

    private var project: Project? { model.projects.first { $0.id == projectId } }
    private var chosen: [CpContact] { model.contacts.filter { selectedContacts.contains($0.id) } }

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        contactsCard
                        projectCard
                        if let project {
                            composer(project)
                        } else if selectedContacts.isEmpty {
                            ContentUnavailableView("Pick contacts and a project",
                                systemImage: "building.2",
                                description: Text("A personalised WhatsApp message is composed for each contact."))
                                .padding(.top, 20)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("WhatsApp Broadcast")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
        .alert("Broadcast", isPresented: Binding(get: { message != nil },
                                                 set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    // MARK: 1. Contacts

    private var contactsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("1. Contacts")
                if !selectedContacts.isEmpty {
                    Text("\(selectedContacts.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.brandTeal, in: Circle())
                }
                Spacer()
                if !model.contacts.isEmpty {
                    Button(selectedContacts.count == model.contacts.count ? "Clear all" : "Select all") {
                        selectedContacts = selectedContacts.count == model.contacts.count
                            ? []
                            : Set(model.contacts.map(\.id))
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            if model.contacts.isEmpty {
                Text("No contacts yet. Add them in Contacts.")
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.contacts) { contact in
                            let on = selectedContacts.contains(contact.id)
                            Button {
                                if on { selectedContacts.remove(contact.id) }
                                else { selectedContacts.insert(contact.id) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: on ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(on ? Color.brandTeal : Color.dealioTextSecondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(contact.name.nilIfEmpty ?? "Contact")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Color.dealioTextPrimary)
                                        Text([contact.dialable.nilIfEmpty, contact.bhkPreference?.nilIfEmpty]
                                                .compactMap { $0 }.joined(separator: " · "))
                                            .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    // MARK: 2. Project

    private var projectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("2. Project")
            if model.projects.isEmpty {
                Text("No projects available.").font(.caption).foregroundStyle(Color.dealioTextSecondary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.projects) { candidate in
                            let on = candidate.id == projectId
                            Button { projectId = candidate.id; custom = "" } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: on ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(on ? Color.brandTeal : Color.dealioTextSecondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(candidate.name)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Color.dealioTextPrimary)
                                        Text([candidate.city?.nilIfEmpty,
                                              candidate.priceLow.map { "from \(Fmt.compactPrice($0))" } ?? "Price on request"]
                                                .compactMap { $0 }.joined(separator: " · "))
                                            .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    // MARK: 3. Composer

    private func composer(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("3. Message preview")
                Spacer()
                Text("\(selectedContacts.count) recipient\(selectedContacts.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            }

            TextEditor(text: Binding(
                get: { custom.isEmpty ? broadcastMessage(model.contacts.first?.name.nilIfEmpty ?? "[Name]", project) : custom },
                set: { custom = $0 }
            ))
            .font(.system(size: 13))
            .frame(minHeight: 150)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color.dealioFieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
            )

            Text("Each contact is greeted by their own name automatically. WhatsApp opens \(broadcastBatch) chats at a time — send, come back, and pick the next few.")
                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { send(project) } label: {
                Label("Send via WhatsApp (\(min(selectedContacts.count, broadcastBatch)))",
                      systemImage: "paperplane.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(selectedContacts.isEmpty ? Color(hex: 0xB7E4C7) : Color(hex: 0x25D366),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedContacts.isEmpty)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func send(_ project: Project) {
        let batch = chosen.prefix(broadcastBatch)
        guard !batch.isEmpty else { return }
        for contact in batch where !contact.phone.isEmpty {
            let text = custom.trimmedOrNil ?? broadcastMessage(contact.name.nilIfEmpty ?? "there", project)
            if let url = Share.whatsAppURL(phone: contact.dialable, text: text) { openURL(url) }
        }
        // The ones already opened come off the list, so tapping again picks up
        // where it left off rather than re-messaging the same three people.
        for contact in batch { selectedContacts.remove(contact.id) }
        if selectedContacts.isEmpty {
            message = "That's everyone."
        } else {
            message = "\(selectedContacts.count) left — tap Send again for the next \(min(selectedContacts.count, broadcastBatch))."
        }
    }

    private func broadcastMessage(_ contactName: String, _ project: Project) -> String {
        let price = project.priceLow.map { "\(Fmt.shortRupee($0))+" } ?? "Price on request"
        let configs = (project.configurations ?? []).filter { !$0.isEmpty }.joined(separator: " / ")
        let options = configs.isEmpty ? "Multiple options" : "\(configs) options available"
        return """
        Hi \(contactName)! 👋

        I wanted to share an exciting property with you:

        🏠 *\(project.name)*
        📍 \(project.city ?? "")
        💰 Starting \(price)
        🏗️ \(options)

        I'd love to arrange a site visit at your convenience. Reply or call me anytime!
        """
    }
}
