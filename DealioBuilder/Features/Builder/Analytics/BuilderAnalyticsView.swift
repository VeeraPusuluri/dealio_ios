import SwiftUI
import Charts

/// The builder's numbers, derived rather than fetched.
///
/// There is no analytics endpoint: every figure here is computed from the same
/// projects / leads / deals the rest of the app already loads, which is why they
/// can never disagree with the lists they came from. Mirrors Android's
/// `ui/builder/analytics/AnalyticsScreen.kt`.

@MainActor
final class BuilderAnalyticsModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var leads: [Lead] = []
    @Published var deals: [Deal] = []
    @Published var loading = true
    @Published var error: String?

    func load(builderId: Int) async {
        loading = deals.isEmpty && leads.isEmpty
        error = nil
        async let projectsRequest: [Project] = APIClient.shared.get("/builder/\(builderId)/projects")
        async let leadsRequest: [Lead] = APIClient.shared.get("/builder/\(builderId)/leads")
        async let dealsRequest: [Deal] = APIClient.shared.get("/builder/\(builderId)/deals")
        do {
            projects = try await projectsRequest
        } catch { self.error = authMessage(error) }
        leads = (try? await leadsRequest) ?? []
        deals = (try? await dealsRequest) ?? []
        loading = false
    }

    /// Money in the bank, not money in the pipeline — only the deals that
    /// actually landed.
    var bookedDeals: [Deal] {
        deals.filter { ["Booked", "Closed"].contains(DealFlow.canonicalStage($0.status) ?? "") }
    }
    var revenue: Double { bookedDeals.compactMap(\.dealValue).reduce(0, +) }
    var averageDeal: Double { bookedDeals.isEmpty ? 0 : revenue / Double(bookedDeals.count) }
    var pipelineValue: Double { deals.compactMap(\.dealValue).reduce(0, +) }
    var conversion: Int { leads.isEmpty ? 0 : bookedDeals.count * 100 / leads.count }

    /// Deals per stage, on the canonical ladder and in ladder order — grouping on
    /// the raw status would split "Booked" from "booked" and file a legacy
    /// spelling under its own bar.
    var byStage: [StageBar] {
        let counts = Dictionary(grouping: deals) { DealFlow.canonicalStage($0.status) ?? "Unrecognised" }
            .mapValues(\.count)
        let ordered = DealFlow.stages.compactMap { stage in
            counts[stage].map { StageBar(stage: stage, count: $0) }
        }
        let unknown = counts["Unrecognised"].map { [StageBar(stage: "Unrecognised", count: $0)] } ?? []
        return ordered + unknown
    }
}

struct StageBar: Identifiable {
    let stage: String
    let count: Int
    var id: String { stage }
}

struct BuilderAnalyticsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderAnalyticsModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if model.loading {
                    ProgressView().padding(.top, 40)
                } else if let error = model.error, model.deals.isEmpty {
                    VStack(spacing: 14) {
                        ErrorBanner(message: error)
                        Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    HStack(spacing: 12) {
                        StatCard(title: "Projects", value: "\(model.projects.count)",
                                 systemImage: "building.2", tint: .brandTeal)
                        StatCard(title: "Total leads", value: "\(model.leads.count)",
                                 systemImage: "person.2", tint: .orange)
                    }
                    HStack(spacing: 12) {
                        StatCard(title: "Conversion", value: "\(model.conversion)%",
                                 systemImage: "chart.line.uptrend.xyaxis", tint: .green)
                        StatCard(title: "Avg deal", value: Fmt.shortRupee(model.averageDeal),
                                 systemImage: "indianrupeesign.circle", tint: .brandTeal)
                    }
                    HStack(spacing: 12) {
                        StatCard(title: "Revenue booked", value: Fmt.shortRupee(model.revenue),
                                 systemImage: "checkmark.seal", tint: .green)
                        StatCard(title: "In pipeline", value: Fmt.shortRupee(model.pipelineValue),
                                 systemImage: "rectangle.stack", tint: .indigo)
                    }

                    stageChart
                }
            }
            .padding()
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) }
    }

    private var stageChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deals by stage").font(.subheadline.weight(.bold))
            if model.byStage.isEmpty {
                Text("No deals yet.").font(.caption).foregroundStyle(Color.dealioTextSecondary)
            } else {
                Chart(model.byStage) { bar in
                    BarMark(x: .value("Count", bar.count), y: .value("Stage", bar.stage))
                        .foregroundStyle(statusColor(bar.stage))
                        .cornerRadius(5)
                        .annotation(position: .trailing) {
                            Text("\(bar.count)").font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                        }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(model.byStage.count) * 34 + 20)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }
}
