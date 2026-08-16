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

@MainActor
final class BuilderPipelineModel: ObservableObject {
    @Published var leads: [Lead] = []
    @Published var loading = true
    @Published var error: String?
    @Published var moving: String?
    @Published var toast: String?

    func load(builderId: Int) async {
        loading = leads.isEmpty
        error = nil
        do { leads = try await APIClient.shared.get("/builder/\(builderId)/leads") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    /// Moves a lead up the ladder. The API keys on the canonical spaced label.
    func move(builderId: Int, leadId: String, to stage: String) async {
        struct Body: Encodable { let stage: String }
        moving = leadId
        defer { moving = nil }
        do {
            try await APIClient.shared.call(
                "/builder/\(builderId)/leads/\(leadId)/stage",
                method: "PATCH",
                body: Body(stage: stageWireValue(stage))
            )
            toast = "Moved to \(stage)"
        } catch {
            toast = authMessage(error)
        }
        await load(builderId: builderId)
    }

    func stage(of lead: Lead) -> String { stageLabel(lead.stage) }

    func counts(by grouping: PipelineGrouping) -> [String: Int] {
        switch grouping {
        case .stage:
            return Dictionary(grouping: leads, by: { stage(of: $0) }).mapValues(\.count)
        case .baton:
            return Dictionary(grouping: leads, by: { BatonGroup.of(stage(of: $0)).rawValue }).mapValues(\.count)
        }
    }
}

/// The lead board, cut either by where a lead is or by who owes its next move.
///
/// The stage cut used to be re-derived here with substring matching over six
/// invented column names, so a loan-sanctioned row filed under "Closed" while
/// the deal screen called the same row "Booked". Both cuts now come off the one
/// canonical ladder, and the baton cut is the answer to the question a stage
/// column cannot answer: which of these is waiting on *me*?
struct BuilderPipelineView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderPipelineModel()
    @State private var grouping: PipelineGrouping = .baton

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $grouping) {
                ForEach(PipelineGrouping.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if model.leads.isEmpty {
                    ContentUnavailableView(
                        "No leads in the pipeline",
                        systemImage: "rectangle.stack",
                        description: Text("Leads referred by your channel partners appear here.")
                    )
                } else if grouping == .stage {
                    stageList
                } else {
                    batonList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Pipeline")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .alert("Pipeline", isPresented: .constant(model.toast != nil)) {
            Button("OK") { model.toast = nil }
        } message: {
            Text(model.toast ?? "")
        }
    }

    private var stageList: some View {
        List {
            ForEach(LEAD_STAGES, id: \.self) { stage in
                let group = model.leads.filter { model.stage(of: $0) == stage }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { row($0) }
                    } header: {
                        header(stage, count: group.count)
                    }
                }
            }
            // Rows on a stage the ladder doesn't recognise would otherwise
            // vanish from the board entirely.
            let stray = model.leads.filter { !LEAD_STAGES.contains(model.stage(of: $0)) }
            if !stray.isEmpty {
                Section {
                    ForEach(stray) { row($0) }
                } header: {
                    header("Other", count: stray.count)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var batonList: some View {
        List {
            ForEach(BatonGroup.allCases) { bucket in
                let group = model.leads.filter { BatonGroup.of(model.stage(of: $0)) == bucket }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { row($0) }
                    } header: {
                        header(bucket.title, count: group.count)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func header(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary)
        }
    }

    private func row(_ lead: Lead) -> some View {
        let stage = model.stage(of: lead)
        let next = NEXT_STAGES[stage] ?? []
        return HStack(spacing: 12) {
            InitialsAvatar(name: lead.customerName, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(lead.customerName ?? "Customer").font(.subheadline.weight(.semibold))
                Text([lead.projectName, batonOf(stage).action]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            if let value = lead.dealValue ?? lead.budget, value > 0 {
                Text(Money.inr(value)).font(.caption.weight(.bold)).foregroundStyle(.brandTeal)
            }
            if !next.isEmpty {
                Menu {
                    ForEach(next, id: \.self) { target in
                        Button(target) {
                            Task {
                                if let id = await auth.resolvedBuilderId() {
                                    await model.move(builderId: id, leadId: lead.id, to: target)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.forward.circle")
                        .font(.title3)
                        .foregroundStyle(.brandTeal)
                }
                .disabled(model.moving == lead.id)
            }
        }
    }
}
