import SwiftUI

// MARK: - The lead board's stages

/// The columns on the lead board — the ladder up to the conversion point, not
/// the whole of it.
///
/// Derived from the canonical ladder rather than hand-listed: these were once
/// two hand-maintained lists that had already drifted. Everything from
/// Negotiation on is a deal and lives on the Deals screen; the server no longer
/// returns those rows from `/leads`, so keeping their columns here would render
/// stages that can never fill. Mirrors Android's `pipeline/LeadStages.kt`.
enum LeadStages {
    static let all = DealFlow.stages.filter { DealFlow.isLeadStage($0) }

    /// Allowed forward transitions from each stage.
    static let next: [String: [String]] = [
        "New Lead": ["Profile Created", "Meeting Requested", "Negotiation", "Closed"],
        "Profile Created": ["Meeting Requested", "Negotiation", "Closed"],
        "Meeting Requested": ["Meeting Confirmed", "Meeting Done", "Negotiation", "Closed"],
        "Meeting Confirmed": ["Meeting Done", "Negotiation", "Closed"],
        "Meeting Done": ["Negotiation", "Agreement", "Booked", "Closed"],
        "Negotiation": ["Agreement", "Booked", "Closed"],
        "Agreement": ["Pending Booking", "Booked", "Closed"],
        "Pending Booking": ["Booked", "Closed"],
        "Booked": ["Closed"],
        "Closed": [],
    ]

    /// A raw `stage` off the wire, folded onto the canonical ten.
    ///
    /// The enum spellings arrive underscored (`MEETING_REQUESTED`), which the
    /// shared alias table does not carry, so they are unpicked to words first.
    /// Anything the ladder still doesn't recognise is returned untouched — the
    /// baton grouping gathers those into their own section rather than guessing.
    static func label(_ raw: String?) -> String {
        let raw = raw ?? ""
        return DealFlow.canonicalStage(raw.replacingOccurrences(of: "_", with: " ")) ?? raw
    }

    /// The value `PATCH /builder/:builderId/leads/:dealId/stage` expects — the
    /// canonical spaced label, unchanged. It keys on the spaced labels, so
    /// SCREAMING_CASE comes back `400 Unknown stage`.
    static func wireValue(_ label: String) -> String {
        DealFlow.canonicalStage(label) ?? label
    }
}

/// A lead row with its raw id and resolved display stage.
struct LeadRowItem: Identifiable, Hashable {
    let id: String
    let lead: Lead
    let stage: String

    static func == (a: LeadRowItem, b: LeadRowItem) -> Bool { a.id == b.id && a.stage == b.stage }
    func hash(into hasher: inout Hasher) { hasher.combine(id); hasher.combine(stage) }
}

/// How the pipeline is cut: by where a lead is, or by who owes its next move.
enum PipelineGrouping: String, CaseIterable { case stage = "By stage", baton = "By baton" }

// MARK: - Models

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
    @Published var rows: [LeadRowItem] = []
    @Published var loading = true
    @Published var error: String?
    @Published var updating = false
    @Published var toast: String?
    @Published var selectedStage = LeadStages.all.first ?? "New Lead"
    @Published var grouping: PipelineGrouping = .stage

    private var builderId = 0

    var counts: [String: Int] {
        Dictionary(rows.map { ($0.stage, 1) }, uniquingKeysWith: +)
    }
    var visible: [LeadRowItem] { rows.filter { $0.stage == selectedStage } }

    /// Leads keyed by who owes the next move.
    ///
    /// A lead lands in one bucket — its first holder — even at Agreement, where
    /// both the partner and the buyer are owed independently; the card says so.
    /// The agreement flags aren't on the leads payload, so neither side can be
    /// struck off here the way the deal screen strikes them off.
    var batonGroups: [String: [LeadRowItem]] {
        Dictionary(grouping: rows) { row in
            guard DealFlow.canonicalStage(row.stage) != nil else { return BatonBucket.unknown }
            return DealFlow.baton(row.stage).holders.first?.rawValue ?? BatonBucket.complete
        }
    }

    func load(builderId: Int, silent: Bool = false) async {
        self.builderId = builderId
        if !silent { loading = rows.isEmpty; error = nil }
        do {
            let leads: [Lead] = try await APIClient.shared.get("/builder/\(builderId)/leads")
            // The server partitions /leads and /deals, so this filter is normally
            // a no-op. It is kept because the app ships ahead of the backend and
            // behind it: against a deployment that still returns every row from
            // /leads, without this the board would show booked deals as leads.
            rows = leads
                .filter { DealFlow.isLeadStage($0.stage) }
                .map { LeadRowItem(id: $0.id, lead: $0, stage: LeadStages.label($0.stage)) }
        } catch { self.error = authMessage(error) }
        loading = false
    }

    func move(_ row: LeadRowItem, to stage: String) async {
        struct Body: Encodable { let stage: String }
        guard let dealId = row.lead.dealId else { return }
        updating = true
        defer { updating = false }
        do {
            try await APIClient.shared.patchVoid("/builder/\(builderId)/leads/\(dealId)/stage",
                                                 body: Body(stage: LeadStages.wireValue(stage)))
            // Crossing into Negotiation converts the lead. The row stops being a
            // lead at that moment, so it leaves the board rather than sitting in
            // a column the board no longer renders — and the toast says where it
            // went, because a card that simply vanished would read as a failure.
            if DealFlow.isDealStage(stage) {
                let first = (row.lead.customerName ?? "The lead").split(separator: " ").first.map(String.init) ?? "The lead"
                toast = "\(first) is now a deal — see Deals"
                rows.removeAll { $0.id == row.id }
            } else {
                toast = "Moved to \(stage)"
                if let index = rows.firstIndex(where: { $0.id == row.id }) {
                    rows[index] = LeadRowItem(id: row.id, lead: row.lead, stage: stage)
                }
            }
        } catch { toast = authMessage(error) }
    }
}

/// The buckets the baton grouping offers, in the order a builder should read
/// them. `complete` is a real answer (nobody owes anything); `unknown` collects
/// rows whose stage isn't on the canonical ladder — surfacing them rather than
/// filing them under a guess, since a status the app doesn't recognise is a data
/// problem worth seeing.
enum BatonBucket {
    static let complete = "complete"
    static let unknown = "unknown"
    static let order = [DealRole.builder.rawValue, DealRole.cp.rawValue,
                        DealRole.customer.rawValue, complete, unknown]

    static func title(_ key: String) -> (String, String) {
        switch key {
        case DealRole.builder.rawValue: return ("Your move", "Nothing on these moves until you act")
        case DealRole.cp.rawValue: return ("With the channel partner", "Waiting on the partner who referred them")
        case DealRole.customer.rawValue: return ("With the buyer", "Waiting on the buyer")
        case complete: return ("Complete", "Nobody owes a move")
        default: return ("Stage not recognised", "These carry a status the app can't place on the ladder")
        }
    }
}

/// The move this lead is waiting on, phrased as an instruction.
///
/// At Agreement both the partner and the buyer are owed, and the leads payload
/// carries neither agreement flag — so the card says both are outstanding rather
/// than implying the one bucket it was filed under is the whole story.
private func batonNote(_ stage: String) -> String? {
    guard DealFlow.canonicalStage(stage) != nil else { return nil }
    let baton = DealFlow.baton(stage)
    guard !baton.isComplete else { return nil }
    let others = baton.holders.dropFirst()
    guard !others.isEmpty else { return baton.action }
    return baton.action + " · also waiting on " + others.map { $0.rawValue }.joined(separator: " and ")
}

// MARK: - Screen

/// The builder's lead board — the same leads cut two ways.
///
/// Stage answers "what does my funnel look like"; baton answers "what do I have
/// to do today", which the stage filter never could. Mirrors Android's
/// `ui/builder/pipeline/PipelineScreen.kt`.
struct BuilderPipelineView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderPipelineModel()
    @State private var sheetRow: LeadRowItem?

    var body: some View {
        VStack(spacing: 0) {
            groupingPills

            if model.grouping == .stage { stageChips }

            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.error, model.rows.isEmpty {
                    VStack(spacing: 14) {
                        ErrorBanner(message: error)
                        Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                } else if model.rows.isEmpty {
                    ContentUnavailableView("No leads yet", systemImage: "person.2",
                        description: Text("Leads appear here as channel partners refer them."))
                } else if model.grouping == .baton {
                    batonList
                } else if model.visible.isEmpty {
                    ContentUnavailableView("No leads in \(model.selectedStage)", systemImage: "person.2",
                        description: Text("Leads in this stage will appear here."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(model.visible) { row in
                                Button { sheetRow = row } label: { LeadBoardCard(row: row) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await reload() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Pipeline")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(item: $sheetRow) { row in
            LeadMoveSheet(row: row, updating: model.updating) { stage in
                sheetRow = nil
                Task { await model.move(row, to: stage) }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Pipeline", isPresented: Binding(get: { model.toast != nil },
                                                set: { if !$0 { model.toast = nil } })) {
            Button("OK", role: .cancel) { model.toast = nil }
        } message: { Text(model.toast ?? "") }
    }

    private func reload() async {
        if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) }
    }

    private var groupingPills: some View {
        HStack(spacing: 8) {
            ForEach(PipelineGrouping.allCases, id: \.self) { option in
                let selected = model.grouping == option
                Button { withAnimation(.snappy) { model.grouping = option } } label: {
                    Text(option.rawValue)
                        .font(.caption.weight(selected ? .bold : .medium))
                        .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(selected ? Color.brandTeal : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? Color.brandTeal : Color.dealioCardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(model.rows.count) leads")
                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var stageChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LeadStages.all, id: \.self) { stage in
                    let selected = model.selectedStage == stage
                    let count = model.counts[stage] ?? 0
                    Button { withAnimation(.snappy) { model.selectedStage = stage } } label: {
                        HStack(spacing: 6) {
                            Text(stage)
                                .font(.caption.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
                            Text("\(count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(selected ? .white : Color.brandTeal)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(selected ? Color.white.opacity(0.22) : Color.brandTeal.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selected ? Color.dealioNavyMid : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? Color.dealioNavyMid : Color.dealioCardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
        }
    }

    private var batonList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                let groups = model.batonGroups
                ForEach(BatonBucket.order, id: \.self) { key in
                    let rows = groups[key] ?? []
                    if !rows.isEmpty {
                        batonHeader(key, rows.count)
                        ForEach(rows) { row in
                            Button { sheetRow = row } label: {
                                LeadBoardCard(row: row, note: batonNote(row.stage))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .refreshable { await reload() }
    }

    private func batonHeader(_ key: String, _ count: Int) -> some View {
        let (title, blurb) = BatonBucket.title(key)
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Color.dealioTextPrimary)
                Text(blurb).font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.bold)).foregroundStyle(Color.brandTeal)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color.brandTeal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.top, 4)
    }
}

private struct LeadBoardCard: View {
    let row: LeadRowItem
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.lead.customerName?.nilIfEmpty ?? "Lead")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text(row.lead.projectName?.nilIfEmpty ?? "—")
                        .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                }
                Spacer()
                if let budget = row.lead.budget, budget > 0 {
                    Text(Money.inr(budget))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                }
            }
            if let note {
                Text(note)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.brandTeal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                StatusBadge(text: row.stage, color: statusColor(row.stage))
                Text((row.lead.cpName?.nilIfEmpty).map { "via \($0)" } ?? "Direct")
                    .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                Spacer()
                if let days = row.lead.daysInStage, days > 0 {
                    Text("\(days)d in stage")
                        .font(.caption2)
                        .foregroundStyle(days >= DealFlow.stalledAfterDays ? Color.dealioStatusAmber : Color.dealioTextSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

private struct LeadMoveSheet: View {
    let row: LeadRowItem
    let updating: Bool
    let onMove: (String) -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(row.lead.customerName?.nilIfEmpty ?? "Lead")
                        .font(.title3.weight(.bold))
                    StatusBadge(text: row.stage, color: statusColor(row.stage))

                    VStack(spacing: 2) {
                        InfoLine("Project", row.lead.projectName?.nilIfEmpty ?? "—")
                        InfoLine("Phone", row.lead.phone?.nilIfEmpty ?? "Contact via channel partner")
                        InfoLine("Email", row.lead.email?.nilIfEmpty ?? "—")
                        InfoLine("Budget", (row.lead.budget ?? 0) > 0 ? Money.inr(row.lead.budget) : "—")
                        InfoLine("Channel partner", row.lead.cpName?.nilIfEmpty ?? "Direct")
                    }
                    .padding(.top, 6)

                    if let phone = row.lead.phone, !phone.isEmpty {
                        Button {
                            if let url = Share.telURL(phone) { openURL(url) }
                        } label: {
                            Label("Call \((row.lead.customerName ?? "").split(separator: " ").first.map(String.init) ?? "lead")",
                                  systemImage: "phone")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.brandTeal, lineWidth: 1)
                                )
                                .foregroundStyle(Color.brandTeal)
                        }
                        .buttonStyle(.plain)
                    }

                    let next = LeadStages.next[row.stage] ?? []
                    if !next.isEmpty, row.lead.dealId != nil {
                        Text("MOVE TO")
                            .font(.caption.weight(.bold)).tracking(1)
                            .foregroundStyle(Color.dealioTextSecondary)
                            .padding(.top, 10)
                        ForEach(next, id: \.self) { stage in
                            // Picking one of these takes the lead across the line
                            // and off this board. Say so on the row itself — the
                            // builder should know before tapping, not after.
                            let converts = DealFlow.isDealStage(stage)
                            Button { onMove(stage) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(stage).font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.dealioTextPrimary)
                                        if converts {
                                            Text("Converts to a deal")
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(Color.brandTeal)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right").foregroundStyle(Color.brandTeal)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 13)
                                .background(Color.dealioNavyMid.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(updating)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
