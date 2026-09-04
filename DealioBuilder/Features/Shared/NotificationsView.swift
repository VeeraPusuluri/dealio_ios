import SwiftUI

/// The notification list, for all three portals.
///
/// One screen serves the builder, the CP and the buyer — only the endpoint
/// prefix and the portal a link is resolved against differ. Mirrors Android's
/// three `…NotificationsScreen.kt` files, which are the same screen three times.
///
/// Read is an explicit act: tapping one marks it, or "Mark all read" does the
/// lot. Marking everything on open made the unread dots decoration — they could
/// never survive the load that drew them — and silently cleared alerts nobody
/// had looked at.

@MainActor
final class NotificationsModel: ObservableObject {
    @Published var items: [BuilderNotification] = []
    @Published var loading = true
    @Published var error: String?

    private let prefix: String

    /// - `prefix`: the endpoint root — "/builder", "/cp" or "/customer".
    init(prefix: String) { self.prefix = prefix }

    var unreadCount: Int { items.filter { $0.read != true }.count }

    func load() async {
        loading = items.isEmpty
        error = nil
        do { items = try await APIClient.shared.get("\(prefix)/notifications") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func markAllRead() async {
        try? await APIClient.shared.patchVoid("\(prefix)/notifications/read-all")
        for index in items.indices { items[index].read = true }
    }

    /// Persist the read *before* redrawing: the list endpoint can serve
    /// unread-only, so a purely local flag would be undone by the next load.
    func markRead(_ id: Int) async {
        guard items.contains(where: { $0.id == id && $0.read != true }) else { return }
        try? await APIClient.shared.patchVoid("\(prefix)/notifications/\(id)/read")
        if let index = items.firstIndex(where: { $0.id == id }) { items[index].read = true }
    }
}

struct NotificationsView: View {
    let portal: DeepLinkPortal
    var emptyHint = "Lead and deal updates will appear here."

    @StateObject private var model: NotificationsModel
    @EnvironmentObject private var deepLink: DeepLinkCenter

    init(portal: DeepLinkPortal, emptyHint: String = "Lead and deal updates will appear here.") {
        self.portal = portal
        self.emptyHint = emptyHint
        _model = StateObject(wrappedValue: NotificationsModel(prefix: portal.endpointPrefix))
    }

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.items.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await model.load() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else if model.items.isEmpty {
                ContentUnavailableView("You're all caught up", systemImage: "bell.slash",
                                       description: Text(emptyHint))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.items) { item in
                            Button {
                                // Reading an alert and going to what it is about
                                // are one act: the same link the tray entry
                                // carries takes you there.
                                Task { await model.markRead(item.id) }
                                deepLink.offer(item.link)
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await model.load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.unreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") { Task { await model.markAllRead() } }
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .task { await model.load() }
    }

    private func row(_ item: BuilderNotification) -> some View {
        let unread = item.read != true
        return HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: icon(item.type), tint: tint(item.type), size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title ?? "Notification")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let message = item.message, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color.dealioTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(shortAgo(item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Color.dealioTextSecondary)
            }
            if unread {
                Circle().fill(Color.brandTeal).frame(width: 8, height: 8).padding(.top, 6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(unread ? Color.brandTeal.opacity(0.45) : Color.dealioCardBorder, lineWidth: 1)
        )
    }

    private func icon(_ type: String?) -> String {
        switch (type ?? "").lowercased() {
        case let t where t.contains("deal"): return "doc.text.fill"
        case let t where t.contains("lead"): return "person.2.fill"
        case let t where t.contains("meeting") || t.contains("visit"): return "calendar"
        case let t where t.contains("message") || t.contains("chat"): return "bubble.left.fill"
        case let t where t.contains("commission") || t.contains("payment"): return "indianrupeesign.circle.fill"
        case let t where t.contains("document"): return "folder.fill"
        default: return "bell.fill"
        }
    }

    private func tint(_ type: String?) -> Color {
        switch (type ?? "").lowercased() {
        case let t where t.contains("deal"): return .brandTeal
        case let t where t.contains("lead"): return .indigo
        case let t where t.contains("meeting") || t.contains("visit"): return .cyan
        case let t where t.contains("commission") || t.contains("payment"): return .green
        default: return .orange
        }
    }
}

// MARK: - Per-portal entry points

struct BuilderNotificationsScreen: View {
    var body: some View {
        NotificationsView(portal: .builder,
                          emptyHint: "Updates on your deals, leads and site visits appear here.")
    }
}

struct CPNotificationsView: View {
    var body: some View {
        NotificationsView(portal: .cp,
                          emptyHint: "Lead and deal updates will appear here.")
    }
}

struct CustomerNotificationsView: View {
    var body: some View {
        NotificationsView(portal: .customer,
                          emptyHint: "Updates on your visits, booking and documents appear here.")
    }
}
