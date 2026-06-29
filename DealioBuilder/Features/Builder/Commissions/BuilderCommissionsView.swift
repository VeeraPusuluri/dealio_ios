import SwiftUI

@MainActor
final class BuilderCommissionsModel: ObservableObject {
    @Published var commissions: [Commission] = []
    @Published var loading = true
    @Published var error: String?

    func load(builderId: Int) async {
        loading = commissions.isEmpty
        error = nil
        do {
            commissions = try await APIClient.shared.get("/builder/\(builderId)/commissions")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    private func isReleased(_ c: Commission) -> Bool {
        (c.status ?? "").lowercased().contains("released") || (c.status ?? "").lowercased() == "paid"
    }
    var released: Double { var s = 0.0; for c in commissions where isReleased(c) { s += c.amount ?? 0 }; return s }
    var pending: Double { var s = 0.0; for c in commissions where !isReleased(c) { s += c.amount ?? 0 }; return s }
}

struct BuilderCommissionsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderCommissionsModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.loading {
                    ProgressView().padding(.top, 40)
                } else if let error = model.error {
                    ErrorBanner(message: error).padding(.horizontal)
                } else {
                    HStack(spacing: 12) {
                        StatCard(title: "Released", value: Money.inr(model.released), systemImage: "checkmark.seal", tint: .green)
                        StatCard(title: "Pending", value: Money.inr(model.pending), systemImage: "hourglass", tint: .orange)
                    }
                    .padding(.horizontal)

                    if model.commissions.isEmpty {
                        ContentUnavailableView("No commissions", systemImage: "indianrupeesign.circle",
                            description: Text("CP commissions on your deals appear here.")).padding(.top, 30)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(model.commissions) { c in
                                HStack(spacing: 12) {
                                    IconBadge(systemImage: "indianrupeesign", tint: .green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.customerName ?? "—").font(.subheadline.weight(.semibold)).lineLimit(1)
                                        Text(c.projectName ?? "—").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(Money.inr(c.amount)).font(.subheadline.weight(.bold))
                                        StatusBadge(text: c.status ?? "Pending", color: statusColor(c.status))
                                    }
                                }
                                .padding(14).frame(maxWidth: .infinity).cardSurface()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Commissions")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
