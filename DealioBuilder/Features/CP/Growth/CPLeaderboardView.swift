import SwiftUI

@MainActor
final class CPGrowthDataModel: ObservableObject {
    @Published var leads: [CpLead] = []
    @Published var profile: CpProfile?
    @Published var loading = true

    func load(cpUserId: Int) async {
        loading = leads.isEmpty && profile == nil
        async let leadsReq: [CpLead] = APIClient.shared.get("/cp/\(cpUserId)/leads")
        async let profileReq: CpProfile = APIClient.shared.get("/cp/\(cpUserId)/profile")
        leads = (try? await leadsReq) ?? []
        profile = try? await profileReq
        loading = false
    }
}

private let monthlyGoal = 5

struct CPLeaderboardView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPGrowthDataModel()

    private var bookedTotal: Int { model.leads.filter { $0.status == "Booked" }.count }
    private var bookedMonth: Int {
        let ym = monthKey(Date())
        return model.leads.filter { $0.status == "Booked" && ($0.createdAt ?? "").hasPrefix(ym) }.count
    }
    private var activeLeads: Int { model.leads.filter { ($0.status ?? "") != "Booked" && ($0.status ?? "") != "Closed" }.count }
    private var totalEarnings: Double { model.leads.filter { $0.status == "Booked" }.reduce(0) { $0 + ($1.estimatedCommission ?? 0) } }
    private var tier: String { bookedTotal >= 20 ? "Platinum" : bookedTotal >= 10 ? "Gold" : bookedTotal >= 5 ? "Silver" : "Bronze" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.loading { ProgressView().padding(.top, 40) } else {
                    // Performance
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            InitialsAvatar(name: model.profile?.fullName ?? auth.user?.fullName, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.profile?.fullName ?? "Partner").font(.headline)
                                Text("\(tier) Tier").font(.caption.weight(.semibold)).foregroundStyle(Color.dealioOrange)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("Earnings").font(.caption2).foregroundStyle(.secondary)
                                Text(Money.inr(totalEarnings)).font(.headline).foregroundStyle(.green)
                            }
                        }
                        Divider()
                        HStack {
                            perf("Total Deals", "\(bookedTotal)", .green)
                            perf("This Month", "\(bookedMonth)", .brandTeal)
                            perf("Active", "\(activeLeads)", .orange)
                        }
                    }
                    .padding(16).cardSurface().padding(.horizontal)

                    // Monthly challenge
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Monthly Challenge", systemImage: "flame").font(.subheadline.weight(.bold))
                        Text("Close \(monthlyGoal) deals this month to unlock the next tier.").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(.tertiarySystemFill)).frame(height: 10)
                                    Capsule().fill(Color.orange).frame(width: geo.size.width * min(Double(bookedMonth) / Double(monthlyGoal), 1), height: 10)
                                }
                            }.frame(height: 10)
                            Text("\(bookedMonth)/\(monthlyGoal)").font(.caption.weight(.bold))
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface().padding(.horizontal)

                    // Tier guide
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tier requirements").font(.subheadline.weight(.bold))
                        ForEach([("Bronze","0–4"),("Silver","5–9"),("Gold","10–19"),("Platinum","20+")], id: \.0) { t in
                            HStack {
                                Text(t.0).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(t.1) deals").font(.caption).foregroundStyle(.secondary)
                                if t.0 == tier { Text("Current").font(.caption2.weight(.bold)).foregroundStyle(.brandTeal) }
                            }
                            .padding(.vertical, 8).overlay(Divider(), alignment: .bottom)
                        }
                    }
                    .padding(16).cardSurface().padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
    }

    private func perf(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

/// "yyyy-MM" key for the given date.
func monthKey(_ date: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.string(from: date)
}

/// Whole days between an ISO-ish "yyyy-MM-dd…" string and now (0 if unparseable).
func daysSince(_ isoDate: String?) -> Int {
    guard let isoDate else { return 0 }
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    guard let date = f.date(from: String(isoDate.prefix(10))) else { return 0 }
    return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
}
