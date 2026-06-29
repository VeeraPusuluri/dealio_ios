import SwiftUI
import Combine

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var leads: [Lead] = []
    @Published var deals: [Deal] = []
    @Published var loading = false
    @Published var errorMessage: String?

    func load(builderId: Int) async {
        loading = true
        errorMessage = nil
        do {
            projects = try await APIClient.shared.get("/builder/\(builderId)/projects")
        } catch let error { setError(error) }
        do {
            leads = try await APIClient.shared.get("/builder/\(builderId)/leads")
        } catch let error { setError(error) }
        do {
            deals = try await APIClient.shared.get("/builder/\(builderId)/deals")
        } catch let error { setError(error) }
        loading = false
    }

    private func setError(_ error: Error) {
        if errorMessage == nil {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    var pipelineValue: Double {
        deals.compactMap(\.dealValue).reduce(0, +)
    }

    var closedDeals: Int {
        deals.filter { statusColor($0.status) == .green }.count
    }
}

struct OverviewView: View {
    @Binding var selection: Int
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var viewModel = OverviewViewModel()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.loading && viewModel.deals.isEmpty && viewModel.projects.isEmpty {
                    loadingState
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage)
                        }

                        heroCard

                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard(title: "Projects", value: "\(viewModel.projects.count)", systemImage: "building.2.fill", tint: .brandTeal, action: { selection = 1 })
                            StatCard(title: "Leads", value: "\(viewModel.leads.count)", systemImage: "person.2.fill", tint: .orange, action: { selection = 2 })
                            StatCard(title: "Active Deals", value: "\(viewModel.deals.count)", systemImage: "doc.text.fill", tint: .blue, action: { selection = 3 })
                            StatCard(title: "Closed", value: "\(viewModel.closedDeals)", systemImage: "checkmark.seal.fill", tint: .green, action: { selection = 3 })
                        }

                        if !viewModel.leads.isEmpty {
                            recentLeads
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let name = auth.user?.fullName { Text(name) }
                        if let phone = auth.user?.phone { Text(phone) }
                        Divider()
                        Button("Sign out", role: .destructive) { auth.logout() }
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.brandTeal)
                    }
                }
            }
            .refreshable { await reload() }
            .task { await reload() }
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    if let name = auth.user?.fullName, !name.isEmpty {
                        Text(name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Pipeline")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(Money.inr(viewModel.pipelineValue))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("Across \(viewModel.deals.count) active deal\(viewModel.deals.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.brand, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .brandTeal.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: Recent leads

    private var recentLeads: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Leads")
            VStack(spacing: 0) {
                let recent = Array(viewModel.leads.prefix(5))
                ForEach(recent) { lead in
                    LeadRow(lead: lead)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    if lead.id != recent.last?.id {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .cardSurface()
        }
    }

    // MARK: Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.brandTeal)
            Text("Loading your workspace…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private func reload() async {
        if auth.builderId == nil { try? await auth.ensureBuilder() }
        guard let id = auth.builderId else { return }
        await viewModel.load(builderId: id)
    }
}
