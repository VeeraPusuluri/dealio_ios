import SwiftUI

struct DealsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var deals: [Deal] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading && deals.isEmpty {
                    LoadingList(rows: 5) { DealRow.placeholder }
                } else if let errorMessage, deals.isEmpty {
                    ScrollView { ErrorBanner(message: errorMessage).padding() }
                } else if deals.isEmpty {
                    ContentUnavailableView(
                        "No deals yet",
                        systemImage: "doc.text",
                        description: Text("Deals progress here as leads convert.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(deals) { deal in
                                DealRow(deal: deal)
                                    .padding(16)
                                    .cardSurface()
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Deals")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        if auth.builderId == nil { try? await auth.ensureBuilder() }
        guard let id = auth.builderId else { loading = false; return }
        do {
            deals = try await APIClient.shared.get("/builder/\(id)/deals")
        } catch let error {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}

struct DealRow: View {
    let deal: Deal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                InitialsAvatar(name: deal.customerName, tint: statusColor(deal.status), size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(deal.customerName ?? "Customer")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let project = deal.projectName, !project.isEmpty {
                        Text(project)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let status = deal.status {
                    StatusBadge(text: status, color: statusColor(status))
                }
            }

            Divider()

            HStack {
                if let cp = deal.cpName, !cp.isEmpty {
                    Label(cp, systemImage: "person.badge.shield.checkmark.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Label("Direct", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Money.inr(deal.dealValue))
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.green)
            }
        }
    }

    /// Redacted placeholder used while loading.
    static var placeholder: some View {
        DealRow(deal: Deal(
            id: Int.random(in: 1...9999),
            status: "Stage",
            dealValue: 7_500_000,
            customerName: "Placeholder Name",
            customerPhone: nil,
            projectName: "Placeholder Project",
            cpName: "Channel Partner",
            createdAt: nil
        ))
    }
}
