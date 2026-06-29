import SwiftUI

@MainActor
final class CPLeadsModel: ObservableObject {
    @Published var leads: [CpLead] = []
    @Published var loading = true
    @Published var error: String?

    func load(cpUserId: Int) async {
        loading = leads.isEmpty
        error = nil
        do {
            leads = try await APIClient.shared.get("/cp/\(cpUserId)/leads")
        } catch { self.error = authMessage(error) }
        loading = false
    }
}

struct CPLeadsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPLeadsModel()
    @State private var query = ""

    private var filtered: [CpLead] {
        query.isEmpty ? model.leads : model.leads.filter {
            ($0.customerName ?? "").localizedCaseInsensitiveContains(query) ||
            ($0.projectName ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.loading {
                    ProgressView()
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if model.leads.isEmpty {
                    ContentUnavailableView("No leads yet",
                        systemImage: "person.2",
                        description: Text("Refer a customer from a project to start a lead."))
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filtered) { lead in
                                NavigationLink {
                                    CPDealDetailView(dealId: lead.id, title: lead.customerName ?? "Lead")
                                } label: { CpLeadRow(lead: lead) }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $query, prompt: "Search leads")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Leads")
            .task { await model.load(cpUserId: auth.user?.id ?? 0) }
            .refreshable { await model.load(cpUserId: auth.user?.id ?? 0) }
        }
    }
}
