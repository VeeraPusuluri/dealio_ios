import SwiftUI

@MainActor
final class BuilderDealsModel: ObservableObject {
    @Published var deals: [Deal] = []
    @Published var loading = true
    @Published var error: String?
    func load(builderId: Int) async {
        loading = deals.isEmpty
        do { deals = try await APIClient.shared.get("/builder/\(builderId)/deals") }
        catch { self.error = authMessage(error) }
        loading = false
    }
}

private let stages = ["New", "Meeting", "Negotiation", "Agreement", "Booked", "Closed"]

struct BuilderPipelineView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealsModel()

    private func stageFor(_ status: String?) -> String {
        let s = (status ?? "").lowercased()
        if s.contains("book") { return "Booked" }
        if s.contains("clos") || s.contains("sold") { return "Closed" }
        if s.contains("agreement") { return "Agreement" }
        if s.contains("negoti") { return "Negotiation" }
        if s.contains("meeting") { return "Meeting" }
        return "New"
    }

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if let error = model.error { ErrorBanner(message: error).padding() }
            else if model.deals.isEmpty {
                ContentUnavailableView("No deals in pipeline", systemImage: "rectangle.stack",
                    description: Text("Customer bookings appear here grouped by stage."))
            } else {
                List {
                    ForEach(stages, id: \.self) { stage in
                        let group = model.deals.filter { stageFor($0.status) == stage }
                        if !group.isEmpty {
                            Section {
                                ForEach(group) { deal in
                                    HStack(spacing: 12) {
                                        InitialsAvatar(name: deal.customerName, size: 38)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(deal.customerName ?? "Customer").font(.subheadline.weight(.semibold))
                                            Text(deal.projectName ?? "—").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(Money.inr(deal.dealValue)).font(.caption.weight(.bold)).foregroundStyle(.brandTeal)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(stage)
                                    Spacer()
                                    Text("\(group.count)").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Pipeline")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
