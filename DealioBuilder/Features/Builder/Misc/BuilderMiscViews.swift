import SwiftUI

// MARK: - CP Performance (computed from deals)

/// One partner's contribution, rolled up from the builder's own deal list.
///
/// `Hashable` so a row can be pushed by value into the breakdown — the ranking
/// alone told a builder who was performing but nothing about *what* they sold.
struct CPStat: Identifiable, Hashable {
    let name: String
    let deals: Int
    let value: Double
    /// Deals still short of booked — the pipeline this partner is sitting on.
    let openDeals: Int
    let bookedDeals: Int
    var id: String { name }

    var averageDealValue: Double { deals > 0 ? value / Double(deals) : 0 }
    /// Share of this partner's deals that reached a booking.
    var conversion: Double { deals > 0 ? Double(bookedDeals) / Double(deals) : 0 }
}

struct BuilderCPPerformanceView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealsModel()

    private var stats: [CPStat] {
        let withCP = model.deals.filter { ($0.cpName ?? "").isEmpty == false }
        let grouped = Dictionary(grouping: withCP, by: { $0.cpName ?? "—" })
        return grouped.map { name, deals in
            var total = 0.0
            var booked = 0
            for deal in deals {
                total += deal.dealValue ?? 0
                if Self.isBooked(deal.status) { booked += 1 }
            }
            return CPStat(name: name, deals: deals.count, value: total,
                          openDeals: deals.count - booked, bookedDeals: booked)
        }.sorted { $0.value > $1.value }
    }

    private var topValue: Double { stats.first?.value ?? 0 }

    /// A deal that reached the money. Same wording `statusColor` treats as green,
    /// so the tick on the card and the count here can never disagree.
    private static func isBooked(_ status: String?) -> Bool {
        let s = (status ?? "").lowercased()
        return s.contains("booked") || s.contains("closed") || s.contains("sold") || s.contains("won")
    }

    var body: some View {
        Group {
            if model.loading && model.deals.isEmpty {
                ProgressView()
            } else if let error = model.error, model.deals.isEmpty {
                ErrorBanner(message: error).padding()
            } else if stats.isEmpty {
                ContentUnavailableView("No CP activity yet", systemImage: "person.2.badge.gearshape",
                    description: Text("Deals brought by channel partners appear here, ranked by value."))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        summaryCard
                        ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                            NavigationLink(value: stat) {
                                row(rank: index + 1, stat: stat)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dealioPageBackground()
        .navigationTitle("CP Performance")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            StatCard(title: "Partners", value: "\(stats.count)",
                     systemImage: "person.2.fill", tint: .indigo)
            StatCard(title: "Sourced value",
                     value: Money.inr(stats.reduce(0) { $0 + $1.value }),
                     systemImage: "indianrupeesign.circle", tint: .brandTeal)
        }
    }

    private func row(rank: Int, stat: CPStat) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(rankColor(rank).opacity(0.15))
                    Text("\(rank)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(rankColor(rank))
                }
                .frame(width: 26, height: 26)

                InitialsAvatar(name: stat.name, tint: rankColor(rank), size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .lineLimit(1)
                    Text("\(stat.deals) deal\(stat.deals == 1 ? "" : "s") · \(stat.bookedDeals) booked")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.inr(stat.value))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.brandTeal)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dealioTextSecondary.opacity(0.6))
                }
            }

            // Bar against the leader, so the ranking reads at a glance.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dealioFieldFill)
                    Capsule()
                        .fill(tintGradient(rankColor(rank)))
                        .frame(width: max(6, geo.size.width * share(stat)))
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stat.name), rank \(rank), \(stat.deals) deals, \(Money.inr(stat.value))")
        .accessibilityHint("Opens this partner's deals")
    }

    private func share(_ stat: CPStat) -> Double {
        topValue > 0 ? min(1, stat.value / topValue) : 0
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .dealioOrange
        case 2: return .indigo
        case 3: return .purple
        default: return .brandTeal
        }
    }
}

// MARK: - One partner's breakdown

/// What a single channel partner actually brought in, and the deals behind it.
///
/// Loads its own deals rather than being handed them, so it can be pushed from
/// the stack root — see `portalDestinations()` for why that matters.
struct BuilderCPDetailView: View {
    let stat: CPStat

    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealsModel()

    private var deals: [Deal] { model.deals.filter { $0.cpName == stat.name } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                metrics
                dealList
            }
            .padding(16)
        }
        .dealioPageBackground()
        .navigationTitle(stat.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }

    private var header: some View {
        VStack(spacing: 10) {
            InitialsAvatar(name: stat.name, tint: .brandTeal, size: 64)
            Text(stat.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.dealioTextPrimary)
                .multilineTextAlignment(.center)
            Text(Money.inr(stat.value))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.brandTeal)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("sourced across \(stat.deals) deal\(stat.deals == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardSurface()
    }

    private var metrics: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(title: "Booked", value: "\(stat.bookedDeals)",
                         systemImage: "checkmark.seal", tint: .green)
                StatCard(title: "In pipeline", value: "\(stat.openDeals)",
                         systemImage: "arrow.triangle.branch", tint: .orange)
            }
            HStack(spacing: 12) {
                StatCard(title: "Average deal", value: Money.inr(stat.averageDealValue),
                         systemImage: "chart.bar", tint: .indigo)
                StatCard(title: "Conversion",
                         value: String(format: "%.0f%%", stat.conversion * 100),
                         systemImage: "target", tint: .brandTeal)
            }
        }
    }

    private var dealList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Deals", subtitle: "Every deal this partner brought")
            if model.loading && deals.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if deals.isEmpty {
                Text("No deals to show.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(deals) { deal in
                    NavigationLink(value: PortalRoute.builderDealDetail(deal.id)) {
                        HStack(spacing: 12) {
                            InitialsAvatar(name: deal.customerName, tint: statusColor(deal.status), size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deal.customerName?.nilIfEmpty ?? "Buyer")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.dealioTextPrimary)
                                    .lineLimit(1)
                                Text(deal.projectName?.nilIfEmpty ?? "—")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(Money.inr(deal.dealValue))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.dealioTextPrimary)
                                StatusBadge(text: deal.status ?? "—", color: statusColor(deal.status))
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.dealioTextSecondary.opacity(0.6))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .cardSurface()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }
}
