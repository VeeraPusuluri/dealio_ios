import SwiftUI

struct LeadsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var leads: [Lead] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading && leads.isEmpty {
                    LoadingList(rows: 6) { LeadRow.placeholder }
                } else if let errorMessage, leads.isEmpty {
                    ScrollView { ErrorBanner(message: errorMessage).padding() }
                } else if leads.isEmpty {
                    ContentUnavailableView(
                        "No leads yet",
                        systemImage: "person.2",
                        description: Text("Leads from bookings and CP shares appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(leads) { lead in
                                LeadRow(lead: lead)
                                    .padding(16)
                                    .cardSurface()
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Leads")
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
            leads = try await APIClient.shared.get("/builder/\(id)/leads")
        } catch let error {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}

struct LeadRow: View {
    let lead: Lead

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: lead.customerName, tint: statusColor(lead.stage))

            VStack(alignment: .leading, spacing: 3) {
                Text(lead.customerName ?? "Unknown")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let project = lead.projectName, !project.isEmpty {
                    Text(project)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let source = lead.source, !source.isEmpty {
                    Text(source.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                if let stage = lead.stage {
                    StatusBadge(text: stage, color: statusColor(stage))
                }
                if let value = lead.dealValue ?? lead.budget, value > 0 {
                    Text(Money.inr(value))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Redacted placeholder used while loading.
    static var placeholder: some View {
        LeadRow(lead: Lead(
            id: UUID().uuidString,
            customerName: "Placeholder Name",
            phone: nil,
            projectName: "Placeholder Project",
            stage: "Stage",
            source: nil,
            budget: 5_000_000,
            dealValue: nil,
            createdAt: nil,
            daysInStage: nil,
            commissionStatus: nil
        ))
    }
}

// MARK: - Loading skeleton

/// A list of redacted card rows shown while content loads — the Apple
/// "skeleton" loading style.
struct LoadingList<Row: View>: View {
    let rows: Int
    @ViewBuilder let row: () -> Row

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<rows, id: \.self) { _ in
                    row()
                        .padding(16)
                        .cardSurface()
                        .redacted(reason: .placeholder)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .allowsHitTesting(false)
    }
}
