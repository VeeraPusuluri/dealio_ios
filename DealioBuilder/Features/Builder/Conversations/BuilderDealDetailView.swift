import SwiftUI

@MainActor
final class BuilderDealDetailModel: ObservableObject {
    @Published var deal: DealDetail?
    @Published var loading = true
    @Published var error: String?
    @Published var sending = false

    func load(builderId: Int, dealId: Int) async {
        loading = deal == nil
        error = nil
        do { deal = try await APIClient.shared.get("/builder/\(builderId)/deals/\(dealId)") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func send(builderId: Int, dealId: Int, text: String) async {
        sending = true
        defer { sending = false }
        _ = try? await APIClient.shared.post("/builder/\(builderId)/deals/\(dealId)/messages",
                                             body: SendMessageRequest(message: text)) as DealDetail?
        await load(builderId: builderId, dealId: dealId)
    }
}

struct BuilderDealDetailView: View {
    let dealId: Int
    let title: String
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealDetailModel()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error {
                ErrorBanner(message: error).padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        let messages = model.deal?.messages ?? []
                        if messages.isEmpty {
                            Text("No messages yet. Say hello to your customer!")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            ForEach(messages) { m in bubble(m) }
                        }
                    }
                    .padding()
                }
                composer
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id, dealId: dealId) } }
    }

    private func bubble(_ m: DealMessage) -> some View {
        let mine = (m.senderRole ?? "").lowercased() == "builder"
        return HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                Text(mine ? "You" : (m.senderRole ?? "").capitalized)
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(m.message).font(.subheadline)
            }
            .padding(10)
            .background(mine ? Color.brandTeal.opacity(0.15) : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Type a message…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            Button {
                let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                draft = ""
                Task { if let id = await auth.resolvedBuilderId() { await model.send(builderId: id, dealId: dealId, text: text) } }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(.brandTeal)
            }
            .disabled(model.sending || draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(.bar)
    }
}
