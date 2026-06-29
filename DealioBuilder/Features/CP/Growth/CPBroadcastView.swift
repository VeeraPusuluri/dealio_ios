import SwiftUI

@MainActor
final class CPBroadcastModel: ObservableObject {
    @Published var contacts: [CpContact] = []
    @Published var projects: [Project] = []
    @Published var loading = true
    func load(cpUserId: Int) async {
        loading = contacts.isEmpty
        async let contactsReq: [CpContact] = APIClient.shared.get("/cp/\(cpUserId)/contacts")
        async let projReq: [Project] = APIClient.shared.get("/customer/projects")
        contacts = (try? await contactsReq) ?? []
        projects = (try? await projReq) ?? []
        loading = false
    }
}

struct CPBroadcastView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPBroadcastModel()
    @Environment(\.openURL) private var openURL
    @State private var selectedContacts: Set<Int> = []
    @State private var projectId: Int?

    private var project: Project? { model.projects.first { $0.id == projectId } }

    private func message(_ contactName: String, _ p: Project) -> String {
        let price = (p.priceMin ?? 0) > 0 ? "Starting \(Money.inr(p.priceMin))" : "Price on request"
        return "Hi \(contactName)! 👋\n\nI wanted to share an exciting property:\n\n🏠 *\(p.name)*\n📍 \(p.city ?? "")\n💰 \(price)\n\nI'd love to arrange a site visit. Reply or call me anytime!"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                } else {
                    // Contacts
                    sectionTitle("1. Contacts (\(selectedContacts.count) selected)")
                    if model.contacts.isEmpty {
                        Text("No contacts yet.").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.contacts) { c in
                                Button {
                                    if selectedContacts.contains(c.id) { selectedContacts.remove(c.id) } else { selectedContacts.insert(c.id) }
                                } label: {
                                    HStack {
                                        Image(systemName: selectedContacts.contains(c.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedContacts.contains(c.id) ? .brandTeal : .secondary)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(c.name ?? "Contact").font(.subheadline.weight(.medium))
                                            Text(c.phone ?? "").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 9)
                                }.buttonStyle(.plain)
                                if c.id != model.contacts.last?.id { Divider() }
                            }
                        }.padding(.horizontal, 14).cardSurface()
                    }

                    // Project
                    sectionTitle("2. Project")
                    if !model.projects.isEmpty {
                        Picker("Project", selection: Binding(get: { projectId ?? -1 }, set: { projectId = $0 })) {
                            Text("Select…").tag(-1)
                            ForEach(model.projects) { Text($0.name).tag($0.id) }
                        }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 6).cardSurface()
                    }

                    // Send
                    if let p = project {
                        sectionTitle("3. Send")
                        Text("A personalised message is composed for each contact. WhatsApp opens for the first few selected.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            let chosen = model.contacts.filter { selectedContacts.contains($0.id) }.prefix(3)
                            for c in chosen {
                                if let phone = c.phone, !phone.isEmpty, let u = Share.whatsAppURL(phone: phone, text: message(c.name ?? "there", p)) { openURL(u) }
                            }
                        } label: {
                            Label("Send via WhatsApp (\(selectedContacts.count))", systemImage: "paperplane.fill").font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(selectedContacts.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(Color(red: 0.14, green: 0.83, blue: 0.4)), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }.disabled(selectedContacts.isEmpty)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("WhatsApp Broadcast")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.caption.weight(.bold)).foregroundStyle(.secondary)
    }
}
