import SwiftUI

// MARK: - Conversations inbox

struct CPConversationsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPLeadsModel()

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if let error = model.error { ErrorBanner(message: error).padding() }
            else if model.leads.isEmpty {
                ContentUnavailableView("No conversations yet", systemImage: "bubble.left.and.bubble.right",
                    description: Text("Refer a lead to start chatting with the customer and builder."))
            } else {
                List(model.leads) { lead in
                    NavigationLink {
                        CPDealDetailView(dealId: lead.id, title: lead.customerName ?? "Conversation")
                    } label: {
                        HStack(spacing: 12) {
                            InitialsAvatar(name: lead.customerName, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lead.customerName ?? "Lead").font(.subheadline.weight(.semibold))
                                Text(lead.projectName ?? "—").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let s = lead.status { StatusBadge(text: s, color: statusColor(s)) }
                        }.padding(.vertical, 4)
                    }
                }.listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Conversations").navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
    }
}

// MARK: - Deal detail + chat

@MainActor
final class CPDealDetailModel: ObservableObject {
    @Published var deal: CpDealDetail?
    @Published var loading = true
    @Published var error: String?

    func load(cpUserId: Int, dealId: Int) async {
        loading = deal == nil
        do { deal = try await APIClient.shared.get("/cp/\(cpUserId)/deals/\(dealId)") }
        catch { self.error = authMessage(error) }
        loading = false
    }
    func send(cpUserId: Int, dealId: Int, text: String) async {
        struct Body: Encodable { let message: String }
        _ = try? await APIClient.shared.post("/cp/\(cpUserId)/deals/\(dealId)/messages", body: Body(message: text)) as CpDealDetail?
        await load(cpUserId: cpUserId, dealId: dealId)
    }
}

struct CPDealDetailView: View {
    let dealId: Int
    let title: String
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPDealDetailModel()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let error = model.error { ErrorBanner(message: error) }
                        let messages = model.deal?.messages ?? []
                        if messages.isEmpty {
                            Text("No messages yet. Reach out to your customer or builder.")
                                .font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            ForEach(messages) { m in bubble(m) }
                        }
                    }.padding()
                }
                HStack(spacing: 10) {
                    TextField("Type a message…", text: $draft, axis: .vertical).lineLimit(1...4)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    Button {
                        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        draft = ""
                        Task { await model.send(cpUserId: auth.user?.id ?? 0, dealId: dealId, text: text) }
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(.brandTeal) }
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }.padding(12).background(.bar)
            }
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0, dealId: dealId) }
    }

    private func bubble(_ m: DealMessage) -> some View {
        let mine = (m.senderRole ?? "").lowercased() == "cp"
        return HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                Text(mine ? "You" : (m.senderRole ?? "").capitalized).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(m.message).font(.subheadline)
            }
            .padding(10).background(mine ? Color.brandTeal.opacity(0.15) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !mine { Spacer(minLength: 40) }
        }
    }
}
