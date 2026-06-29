import SwiftUI
import Charts

@MainActor
final class BuilderAnalyticsModel: ObservableObject {
    @Published var leads: [Lead] = []
    @Published var deals: [Deal] = []
    @Published var loading = true
    func load(builderId: Int) async {
        loading = deals.isEmpty
        async let leadsReq: [Lead] = APIClient.shared.get("/builder/\(builderId)/leads")
        async let dealsReq: [Deal] = APIClient.shared.get("/builder/\(builderId)/deals")
        leads = (try? await leadsReq) ?? []
        deals = (try? await dealsReq) ?? []
        loading = false
    }
}

private struct StageBar: Identifiable { let stage: String; let count: Int; var id: String { stage } }

struct BuilderAnalyticsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderAnalyticsModel()

    private var pipelineValue: Double { model.deals.compactMap(\.dealValue).reduce(0, +) }
    private var booked: Int { model.deals.filter { statusColor($0.status) == .green }.count }
    private var conversion: String {
        model.leads.isEmpty ? "0%" : String(format: "%.0f%%", Double(booked) / Double(model.leads.count) * 100)
    }
    private var byStage: [StageBar] {
        let order = ["New", "Meeting", "Negotiation", "Agreement", "Booked", "Closed"]
        func stage(_ s: String?) -> String {
            let l = (s ?? "").lowercased()
            if l.contains("book") { return "Booked" }; if l.contains("clos") || l.contains("sold") { return "Closed" }
            if l.contains("agreement") { return "Agreement" }; if l.contains("negoti") { return "Negotiation" }
            if l.contains("meeting") { return "Meeting" }; return "New"
        }
        let counts = Dictionary(grouping: model.deals, by: { stage($0.status) }).mapValues(\.count)
        return order.compactMap { name in counts[name].map { StageBar(stage: name, count: $0) } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.loading { ProgressView().padding(.top, 40) } else {
                    HStack(spacing: 12) {
                        StatCard(title: "Pipeline", value: Money.inr(pipelineValue), systemImage: "indianrupeesign.circle", tint: .brandTeal)
                        StatCard(title: "Conversion", value: conversion, systemImage: "chart.line.uptrend.xyaxis", tint: .green)
                    }
                    HStack(spacing: 12) {
                        StatCard(title: "Total Leads", value: "\(model.leads.count)", systemImage: "person.2", tint: .orange)
                        StatCard(title: "Active Deals", value: "\(model.deals.count)", systemImage: "doc.text", tint: .blue)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deals by stage").font(.subheadline.weight(.bold))
                        if byStage.isEmpty {
                            Text("No deals yet.").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Chart(byStage) { bar in
                                BarMark(x: .value("Count", bar.count), y: .value("Stage", bar.stage))
                                    .foregroundStyle(Color.brandTeal).cornerRadius(5)
                                    .annotation(position: .trailing) { Text("\(bar.count)").font(.caption2).foregroundStyle(.secondary) }
                            }
                            .frame(height: CGFloat(byStage.count) * 42 + 20)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
