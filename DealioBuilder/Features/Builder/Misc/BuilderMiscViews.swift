import SwiftUI

// MARK: - CP Performance (computed from deals)

private struct CPStat: Identifiable {
    let name: String; let deals: Int; let value: Double
    var id: String { name }
}

struct BuilderCPPerformanceView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealsModel()

    private var stats: [CPStat] {
        let withCP = model.deals.filter { ($0.cpName ?? "").isEmpty == false }
        let grouped = Dictionary(grouping: withCP, by: { $0.cpName ?? "—" })
        return grouped.map { name, deals in
            var total = 0.0
            for d in deals { total += d.dealValue ?? 0 }
            return CPStat(name: name, deals: deals.count, value: total)
        }.sorted { $0.value > $1.value }
    }

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if let error = model.error { ErrorBanner(message: error).padding() }
            else if stats.isEmpty {
                ContentUnavailableView("No CP activity yet", systemImage: "person.2.badge.gearshape",
                    description: Text("Deals brought by channel partners appear here, ranked by value."))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(stats.enumerated()), id: \.element.id) { idx, s in
                            HStack(spacing: 12) {
                                Text("\(idx + 1)").font(.headline).foregroundStyle(.secondary).frame(width: 24)
                                InitialsAvatar(name: s.name, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(.subheadline.weight(.semibold))
                                    Text("\(s.deals) deal\(s.deals == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Money.inr(s.value)).font(.subheadline.weight(.bold)).foregroundStyle(.brandTeal)
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                        }
                    }.padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("CP Performance").navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
