import SwiftUI

@MainActor
final class CPOverviewModel: ObservableObject {
    @Published var profile: CpProfile?
    @Published var leads: [CpLead] = []
    @Published var dueToday: CpDueToday?
    @Published var loading = true
    @Published var error: String?

    func load(cpUserId: Int) async {
        loading = profile == nil
        error = nil
        do {
            async let profileReq: CpProfile = APIClient.shared.get("/cp/\(cpUserId)/profile")
            async let leadsReq: [CpLead] = APIClient.shared.get("/cp/\(cpUserId)/leads")
            async let dueReq: CpDueToday = APIClient.shared.get("/cp/\(cpUserId)/due-today")
            profile = try await profileReq
            leads = (try? await leadsReq) ?? []
            dueToday = try? await dueReq
        } catch {
            self.error = authMessage(error)
        }
        loading = false
    }
}

struct CPOverviewView: View {
    @EnvironmentObject private var router: PortalRouter
    @Binding var selection: Int
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPOverviewModel()

    private var activeLeads: Int {
        model.leads.filter { $0.status != "Booked" && $0.status != "Closed" }.count
    }

    var body: some View {
        NavigationStack(path: router.path(0)) {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    if model.loading && model.profile == nil {
                        ProgressView().padding(.top, 40)
                    } else if let error = model.error, model.profile == nil {
                        VStack(spacing: 12) {
                            ErrorBanner(message: error)
                            Button("Try again") { Task { await reload() } }
                                .buttonStyle(.borderedProminent)
                                .tint(.brandTeal)
                        }
                        .padding(.horizontal)
                    } else {
                        statGrid
                        dueTodaySection
                        quickActions
                        recentLeads
                    }
                }
                .padding(.bottom, 24)
            }
            .dealioPageBackground()
            // Lets the hero's gradient run up behind the clock instead of
            // stopping at a pale strip under it.
            .heroScrollEdges()
            .portalDestinations()
            .navigationBarHidden(true)
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func reload() async { await model.load(cpUserId: auth.user?.id ?? 0) }

    // MARK: Hero

    private var hero: some View {
        let cp = model.profile?.cp
        let name = model.profile?.fullName ?? auth.user?.fullName ?? "Partner"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                InitialsAvatar(name: name, size: 48)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Welcome back")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dealioTealBright)
                    Text(name.components(separatedBy: " ").first ?? name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                NavigationLink(value: PortalRoute.cpNotifications) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.15), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Notifications")
            }

            NavigationLink(value: PortalRoute.cpProfile) {
                HStack(spacing: 6) {
                    Image(systemName: "rosette").foregroundStyle(Color.dealioOrange)
                    Text("\(cp?.tier ?? "Silver") Partner")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.white.opacity(0.13), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 20)
        .padding(.top, SafeArea.top + 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandHeaderBackground())
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26,
                                          style: .continuous))
    }

    // MARK: Stats

    private var statGrid: some View {
        let cp = model.profile?.cp
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(title: "Earned", value: Money.inr(cp?.totalEarnings),
                         systemImage: "indianrupeesign.circle", tint: .green, action: { selection = 3 })
                StatCard(title: "Pending", value: Money.inr(cp?.pendingCommission),
                         systemImage: "hourglass", tint: .dealioOrange, action: { selection = 3 })
            }
            HStack(spacing: 12) {
                StatCard(title: "Deals", value: "\(cp?.totalDeals ?? 0)",
                         systemImage: "checkmark.seal", tint: .brandTeal, action: { selection = 1 })
                StatCard(title: "Active Leads", value: "\(activeLeads)",
                         systemImage: "person.2", tint: .brandTeal, action: { selection = 1 })
            }
        }
        .padding(.horizontal)
    }

    // MARK: Due today

    private var dueTodaySection: some View {
        let due = model.dueToday
        let count = due?.count ?? 0
        return NavigationLink(value: PortalRoute.cpFollowUps) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Due today").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    if count > 0 {
                        Text("\(count)").font(.caption2.weight(.bold)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.dealioOrange, in: Capsule())
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                if count == 0 {
                    Text("Nothing due today — you're all caught up!")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(due?.meetings ?? []) { m in
                            DueRow(title: m.customerName.nilIfEmpty ?? "Meeting",
                                   subtitle: [m.projectName.nilIfEmpty, m.time?.nilIfEmpty]
                                    .compactMap { $0 }.joined(separator: " · "))
                        }
                        ForEach(due?.followUps ?? []) { f in
                            DueRow(title: f.customerName.nilIfEmpty ?? "Follow-up",
                                   subtitle: [f.projectName, f.reason].compactMap { $0.nilIfEmpty }.joined(separator: " · "))
                        }
                        ForEach(due?.callbacks ?? []) { c in
                            DueRow(title: c.customerName.nilIfEmpty ?? "Callback",
                                   subtitle: [c.projectName, c.status].compactMap { $0.nilIfEmpty }.joined(separator: " · "))
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(.pressable)
        .padding(.horizontal)
    }

    // MARK: Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Quick actions")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button { selection = 2 } label: {
                    QuickActionTile(title: "Projects", systemImage: "building.2")
                }
                .buttonStyle(.pressable)

                // Routed by value: the eager `NavigationLink { CPContactsView() }`
                // form built every one of these screens — and their models — on
                // each render of the home page.
                quickLink("Contacts", "person.crop.circle.badge.plus", .cpContacts)
                quickLink("Follow-ups", "bell.badge", .cpFollowUps)
                quickLink("Meetings", "calendar", .cpMeetings)
            }
        }
        .padding(.horizontal)
    }

    private func quickLink(_ title: String, _ icon: String, _ route: PortalRoute) -> some View {
        NavigationLink(value: route) {
            QuickActionTile(title: title, systemImage: icon)
        }
        .buttonStyle(.pressable)
    }

    // MARK: Recent leads

    private var recentLeads: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Recent leads")
                Spacer()
                if !model.leads.isEmpty {
                    Button("See all") { selection = 1 }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.brandTeal)
                }
            }
            if model.leads.isEmpty {
                Text("No leads yet. Browse projects to add one.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                // Every row opens its deal. They were plain cards before, so the
                // home page listed five leads a partner could not act on.
                ForEach(model.leads.prefix(5)) { lead in
                    NavigationLink(value: PortalRoute.cpDealDetail(lead.id)) {
                        CpLeadRow(lead: lead)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct DueRow: View {
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.dealioOrange).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct QuickActionTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.brandTeal)
                .frame(width: 36, height: 36)
                .background(Color.brandTeal.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title).font(.subheadline.weight(.medium))
                .foregroundStyle(Color.dealioTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.dealioSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.dealioCardBorder, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// Shared lead row used on the CP overview and leads list.
struct CpLeadRow: View {
    let lead: CpLead
    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: lead.customerName, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(lead.customerName.nilIfEmpty ?? "Lead")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)
                Text(lead.projectName.nilIfEmpty ?? "—")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(text: lead.status.nilIfEmpty ?? "Lead", color: statusColor(lead.status))
                if let commission = lead.estimatedCommission, commission > 0 {
                    Text("~\(Money.inr(commission))")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.brandTeal)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.dealioTextSecondary.opacity(0.6))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .cardSurface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the deal")
    }
}
