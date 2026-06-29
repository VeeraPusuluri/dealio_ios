import SwiftUI

struct CustomerConversationsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CustomerDealsModel()

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if let error = model.error { ErrorBanner(message: error).padding() }
            else if model.deals.isEmpty {
                ContentUnavailableView("No conversations yet", systemImage: "bubble.left.and.bubble.right",
                    description: Text("Book a site visit to start chatting with your builder."))
            } else {
                List(model.deals) { deal in
                    NavigationLink {
                        CustomerDealDetailView(deal: deal)
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemImage: "building.2.fill", tint: .brandTeal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deal.projectName ?? "Booking").font(.subheadline.weight(.semibold))
                                Text(deal.builderName ?? "Builder chat").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let s = deal.dealStatus { StatusBadge(text: s, color: statusColor(s)) }
                        }.padding(.vertical, 4)
                    }
                }.listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(phone: auth.phone) }
        .refreshable { await model.load(phone: auth.phone) }
    }
}

private struct CustomerMessageRequest: Encodable {
    let phone: String
    let recipientRole: String
    let message: String
}

struct CustomerDealDetailView: View {
    let deal: CustomerDeal
    @EnvironmentObject private var auth: AuthStore
    @State private var messages: [DealMessage]
    @State private var draft = ""
    @State private var sending = false

    init(deal: CustomerDeal) {
        self.deal = deal
        _messages = State(initialValue: deal.messages ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty {
                        Text("No messages yet. Say hello to your builder!")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        ForEach(messages) { m in bubble(m) }
                    }
                }.padding()
            }
            HStack(spacing: 10) {
                TextField("Type a message…", text: $draft, axis: .vertical).lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                Button { Task { await send() } } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(.brandTeal)
                }.disabled(sending || draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12).background(.bar)
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle(deal.projectName ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""; sending = true; defer { sending = false }
        _ = try? await APIClient.shared.post("/portal/customer/deals/\(deal.dealId)/messages",
            body: CustomerMessageRequest(phone: auth.phone, recipientRole: "builder", message: text)) as CustomerDeal?
        // Optimistically append.
        messages.append(DealMessage(id: Int.random(in: 1...1_000_000), senderRole: "customer", message: text, createdAt: nil))
    }

    private func bubble(_ m: DealMessage) -> some View {
        let mine = (m.senderRole ?? "").lowercased() == "customer"
        return HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                Text(mine ? "You" : (m.senderRole ?? "").capitalized).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(m.message).font(.subheadline)
            }
            .padding(10)
            .background(mine ? Color.brandTeal.opacity(0.15) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !mine { Spacer(minLength: 40) }
        }
    }
}
