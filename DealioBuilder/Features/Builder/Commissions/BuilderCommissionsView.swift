import SwiftUI

@MainActor
final class BuilderCommissionsModel: ObservableObject {
    @Published var commissions: [Commission] = []
    @Published var loading = true
    @Published var working = false
    @Published var error: String?
    @Published var message: String?

    private var builderId = 0

    func load(builderId: Int) async {
        self.builderId = builderId
        loading = commissions.isEmpty
        error = nil
        do {
            commissions = try await APIClient.shared.get("/builder/\(builderId)/commissions")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    /// Pays out the partner who brought the deal.
    ///
    /// A commission row's id *is* its deal id — the backend derives commissions
    /// from deals and releases against the deal, which is the thing that sold.
    func release(_ commission: Commission) async {
        working = true
        defer { working = false }
        do {
            try await APIClient.shared.patchVoid("/builder/\(builderId)/commissions/\(commission.id)/release")
            message = "Commission released"
            await load(builderId: builderId)
        } catch { message = authMessage(error) }
    }

    func isReleased(_ c: Commission) -> Bool {
        let status = (c.status ?? "").lowercased()
        return status.contains("released") || status == "paid"
    }
    var released: Double { var s = 0.0; for c in commissions where isReleased(c) { s += c.amount ?? 0 }; return s }
    var pending: Double { var s = 0.0; for c in commissions where !isReleased(c) { s += c.amount ?? 0 }; return s }
}

struct BuilderCommissionsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderCommissionsModel()
    @State private var releasing: Commission?

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
                                        if !model.isReleased(c) {
                                            Button("Release") { releasing = c }
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Color.dealioStatusGreen)
                                                .disabled(model.working)
                                        }
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
        // Releasing moves real money to the partner, so it asks first.
        .alert("Release this commission?",
               isPresented: Binding(get: { releasing != nil }, set: { if !$0 { releasing = nil } })) {
            Button("Release", role: .destructive) {
                if let target = releasing { Task { await model.release(target) } }
                releasing = nil
            }
            Button("Not yet", role: .cancel) { releasing = nil }
        } message: {
            Text("\(Money.inr(releasing?.amount)) goes to \(releasing?.customerName ?? "the partner")'s deal. This is recorded and the partner is told.")
        }
        .alert("Commissions", isPresented: Binding(get: { model.message != nil },
                                                   set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}
