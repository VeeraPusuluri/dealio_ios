import SwiftUI

// MARK: - Contacts

struct CPContactsView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @State private var contacts: [CpContact] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading { ProgressView() }
            else if let error { ErrorBanner(message: error).padding() }
            else if contacts.isEmpty {
                ContentUnavailableView("No contacts yet", systemImage: "person.crop.circle",
                    description: Text("Add buyers to your CRM to follow up and broadcast to them."))
            } else {
                List(contacts) { c in
                    HStack(spacing: 12) {
                        InitialsAvatar(name: c.name, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name ?? "Contact").font(.subheadline.weight(.semibold))
                            Text([c.phone, c.bhkPreference].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let phone = c.phone, !phone.isEmpty {
                            Button { if let u = Share.telURL(phone) { openURL(u) } } label: { Image(systemName: "phone.fill") }.buttonStyle(.borderless)
                            Button { if let u = Share.whatsAppURL(phone: phone, text: "Hi \(c.name ?? "")!") { openURL(u) } } label: { Image(systemName: "message.fill") }.buttonStyle(.borderless).tint(.green)
                        }
                    }.padding(.vertical, 4)
                }.listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Contacts").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }
    private func load() async {
        loading = contacts.isEmpty
        do { contacts = try await APIClient.shared.get("/cp/\(auth.user?.id ?? 0)/contacts") }
        catch { self.error = authMessage(error) }
        loading = false
    }
}

// MARK: - Follow-ups

struct CPFollowUpsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var items: [CpFollowUp] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading { ProgressView() }
            else if let error { ErrorBanner(message: error).padding() }
            else if items.isEmpty {
                ContentUnavailableView("No follow-ups due", systemImage: "bell.badge",
                    description: Text("Scheduled follow-ups with your leads appear here."))
            } else {
                List(items) { f in
                    HStack(spacing: 12) {
                        IconBadge(systemImage: "bell.fill", tint: .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.customerName ?? "Lead").font(.subheadline.weight(.semibold))
                            Text(f.projectName ?? "—").font(.caption).foregroundStyle(.secondary)
                            if let reason = f.reason, !reason.isEmpty { Text(reason).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text([f.dueDate, f.dueTime].compactMap { $0 }.joined(separator: " ")).font(.caption2).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }.listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Follow-ups").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }
    private func load() async {
        loading = items.isEmpty
        do { items = try await APIClient.shared.get("/cp/\(auth.user?.id ?? 0)/follow-ups") }
        catch { self.error = authMessage(error) }
        loading = false
    }
}

// MARK: - Meetings

struct CPMeetingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var meetings: [CpMeeting] = []
    @State private var loading = true
    @State private var error: String?
    @State private var mode: MeetingViewMode = .list

    private var calMeetings: [CalMeeting] {
        meetings.compactMap { m in
            CalMeeting(id: "\(m.id)", dateString: m.confirmedDate ?? m.preferredDate,
                       time: m.confirmedTime ?? m.preferredTime, title: m.customerName ?? "Visitor",
                       subtitle: nil, status: m.status, color: statusColor(m.status))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(MeetingViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            Group {
                if loading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if let error { ErrorBanner(message: error).padding() }
                else if mode == .calendar {
                    MeetingCalendarView(meetings: calMeetings)
                } else if meetings.isEmpty {
                    ContentUnavailableView("No meetings yet", systemImage: "calendar",
                        description: Text("Site visits you arrange for your leads appear here."))
                } else {
                    List(meetings) { m in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(m.customerName ?? "Visitor").font(.subheadline.weight(.semibold))
                                Spacer()
                                StatusBadge(text: m.status ?? "Pending", color: statusColor(m.status))
                            }
                            if !m.whenText.isEmpty { Label(m.whenText, systemImage: "clock").font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 4)
                    }.listStyle(.insetGrouped)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Meetings").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }
    private func load() async {
        loading = meetings.isEmpty
        do { meetings = try await APIClient.shared.get("/cp/\(auth.user?.id ?? 0)/meetings") }
        catch { self.error = authMessage(error) }
        loading = false
    }
}
