import SwiftUI

@MainActor
final class BuilderBroadcastModel: ObservableObject {
    @Published var broadcasts: [Broadcast] = []
    @Published var loading = true
    @Published var sending = false
    @Published var error: String?

    func load(builderId: Int) async {
        loading = broadcasts.isEmpty
        do { broadcasts = try await APIClient.shared.get("/builder/\(builderId)/broadcasts") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func send(builderId: Int, message: String, audience: String) async {
        sending = true; defer { sending = false }
        _ = try? await APIClient.shared.post("/builder/\(builderId)/broadcasts",
            body: BroadcastRequest(message: message, audience: audience, projectId: nil, projectName: nil)) as Broadcast?
        await load(builderId: builderId)
    }
}

struct BuilderBroadcastView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderBroadcastModel()
    @State private var message = ""
    @State private var audience = "All CPs"
    private let audiences = ["All CPs", "All Customers", "Verified CPs"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Composer
                VStack(alignment: .leading, spacing: 12) {
                    Text("New broadcast").font(.headline)
                    Picker("Audience", selection: $audience) {
                        ForEach(audiences, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                    TextEditor(text: $message).frame(minHeight: 100).font(.subheadline)
                        .padding(8).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                    Button {
                        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        message = ""
                        Task { if let id = await auth.resolvedBuilderId() { await model.send(builderId: id, message: text, audience: audience) } }
                    } label: {
                        Label("Send broadcast", systemImage: "megaphone.fill").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(message.trimmingCharacters(in: .whitespaces).isEmpty ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(LinearGradient.brand), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }.disabled(model.sending || message.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(16).cardSurface()

                // History
                Text("Recent broadcasts").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if model.broadcasts.isEmpty {
                    Text("No broadcasts sent yet.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(model.broadcasts) { b in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(b.audience ?? "All", systemImage: "person.2").font(.caption.weight(.semibold)).foregroundStyle(.brandTeal)
                                Spacer()
                                if let d = b.delivered { Text("\(d) delivered").font(.caption2).foregroundStyle(.secondary) }
                            }
                            Text(b.message).font(.subheadline)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Broadcast")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
