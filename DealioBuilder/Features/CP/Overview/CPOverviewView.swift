import SwiftUI

@MainActor
final class CPOverviewModel: ObservableObject {
    @Published var profile: CpProfile?
    @Published var leads: [CpLead] = []
    @Published var loading = true
    @Published var error: String?

    func load(cpUserId: Int) async {
        loading = profile == nil
        error = nil
        do {
            async let profileReq: CpProfile = APIClient.shared.get("/cp/\(cpUserId)/profile")
            async let leadsReq: [CpLead] = APIClient.shared.get("/cp/\(cpUserId)/leads")
            profile = try await profileReq
            leads = (try? await leadsReq) ?? []
        } catch {
            self.error = authMessage(error)
        }
        loading = false
    }
}

struct CPOverviewView: View {
    @Binding var selection: Int
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPOverviewModel()

    private var activeLeads: Int { model.leads.filter { ($0.status ?? "") != "Booked" && ($0.status ?? "") != "Closed" }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    if model.loading {
                        ProgressView().padding(.top, 40)
                    } else if let error = model.error {
                        ErrorBanner(message: error).padding(.horizontal)
                    } else {
                        statGrid
                        recentLeads
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await model.load(cpUserId: auth.user?.id ?? 0) }
            .refreshable { await model.load(cpUserId: auth.user?.id ?? 0) }
        }
    }

    private var hero: some View {
        let cp = model.profile?.cp
        let name = model.profile?.fullName ?? auth.user?.fullName ?? "Partner"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                InitialsAvatar(name: name, size: 48)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Welcome back").font(.caption.weight(.semibold)).foregroundStyle(Color.dealioTealBright)
                    Text(name.components(separatedBy: " ").first ?? name)
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                }
                Spacer()
            }
            HStack(spacing: 6) {
                Image(systemName: "rosette").foregroundStyle(Color.dealioOrange)
                Text("\(cp?.tier ?? "Silver") Partner").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.white.opacity(0.12), in: Capsule())
        }
        .padding(20)
        .padding(.top, 50)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26, style: .continuous))
        .ignoresSafeArea(edges: .top)
    }

    private var statGrid: some View {
        let cp = model.profile?.cp
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(title: "Earned", value: Money.inr(cp?.totalEarnings), systemImage: "indianrupeesign.circle", tint: .green, action: { selection = 3 })
                StatCard(title: "Pending", value: Money.inr(cp?.pendingCommission), systemImage: "hourglass", tint: .dealioOrange, action: { selection = 3 })
            }
            HStack(spacing: 12) {
                StatCard(title: "Deals", value: "\(cp?.totalDeals ?? 0)", systemImage: "checkmark.seal", tint: .brandTeal, action: { selection = 1 })
                StatCard(title: "Active Leads", value: "\(activeLeads)", systemImage: "person.2", tint: .brandTeal, action: { selection = 1 })
            }
        }
        .padding(.horizontal)
    }

    private var recentLeads: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Recent leads")
                Spacer()
            }
            if model.leads.isEmpty {
                Text("No leads yet. Browse projects to add one.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(model.leads.prefix(5)) { CpLeadRow(lead: $0) }
            }
        }
        .padding(.horizontal)
    }
}

/// Shared lead row used on the CP overview and leads list.
struct CpLeadRow: View {
    let lead: CpLead
    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: lead.customerName, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(lead.customerName ?? "Lead").font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(lead.projectName ?? "—").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(text: lead.status ?? "Lead", color: statusColor(lead.status))
                if let commission = lead.estimatedCommission, commission > 0 {
                    Text("~\(Money.inr(commission))").font(.caption2.weight(.semibold)).foregroundStyle(.brandTeal)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }
}
