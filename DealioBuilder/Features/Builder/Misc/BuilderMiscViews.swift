import SwiftUI

// MARK: - Notifications

struct BuilderNotificationsView: View {
    @State private var items: [BuilderNotification] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading { ProgressView() }
            else if let error { ErrorBanner(message: error).padding() }
            else if items.isEmpty {
                ContentUnavailableView("No notifications", systemImage: "bell",
                    description: Text("Updates on your deals, leads and meetings appear here."))
            } else {
                List(items) { n in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(n.type)).foregroundStyle(.brandTeal).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.title ?? "Notification").font(.subheadline.weight(.semibold))
                            if let m = n.message { Text(m).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if n.read == false { Circle().fill(Color.brandTeal).frame(width: 8, height: 8) }
                    }.padding(.vertical, 4)
                }.listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }
    private func icon(_ type: String?) -> String {
        switch (type ?? "").lowercased() {
        case let t where t.contains("deal"): return "doc.text.fill"
        case let t where t.contains("lead"): return "person.2.fill"
        case let t where t.contains("meeting"): return "calendar"
        default: return "bell.fill"
        }
    }
    private func load() async {
        loading = items.isEmpty
        do { items = try await APIClient.shared.get("/builder/notifications") }
        catch { self.error = authMessage(error) }
        loading = false
    }
}

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

// MARK: - Settings

struct BuilderSettingsView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        List {
            Section("Account") {
                row("Name", auth.user?.fullName ?? "—")
                row("Phone", auth.user?.phone ?? "—")
                row("Email", auth.user?.email ?? "—")
                if let id = auth.builderId { row("Builder ID", "\(id)") }
            }
            Section("About") {
                row("App", "Dealio for Builders")
                row("Backend", "dealio-backend-dev")
            }
            Section {
                Button(role: .destructive) { auth.logout() } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
    }
    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.medium) }
    }
}
