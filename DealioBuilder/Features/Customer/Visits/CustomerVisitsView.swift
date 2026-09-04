import SwiftUI

/// The buyer's site visits — list or calendar, and everything about one of them.
///
/// The two questions a buyer actually has on the day — where is it, and who do I
/// call if I am lost at the gate — had no answer anywhere: the list showed a
/// project name and a time. Both now open the detail sheet. Mirrors Android's
/// `ui/customer/visits/VisitsScreen.kt`.

@MainActor
final class CustomerVisitsModel: ObservableObject {
    @Published var meetings: [CustomerMeeting] = []
    @Published var loading = true
    @Published var error: String?
    @Published var message: String?

    private var phone = ""

    var completed: Int {
        meetings.filter { ($0.status ?? "").caseInsensitiveCompare("Completed") == .orderedSame }.count
    }

    func load(phone: String, silent: Bool = false) async {
        self.phone = phone
        if !silent { loading = meetings.isEmpty; error = nil }
        do { meetings = try await CustomerService.meetings(phone: phone) }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func rate(_ meetingId: Int, _ rating: Int) async {
        do {
            try await CustomerService.rateMeeting(meetingId, rating: rating)
            message = "Thanks for rating your visit!"
            await load(phone: phone, silent: true)
        } catch { message = authMessage(error) }
    }
}

struct CustomerVisitsView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CustomerVisitsModel()
    @State private var mode: MeetingViewMode = .list
    @State private var detail: CustomerMeeting?

    private var calendarMeetings: [CalMeeting] {
        model.meetings.compactMap { meeting in
            CalMeeting(id: "mtg-\(meeting.id)",
                       dateString: meeting.confirmedDate ?? meeting.preferredDate,
                       time: meeting.confirmedTime ?? meeting.preferredTime,
                       title: meeting.projectName?.nilIfEmpty ?? "Site visit",
                       subtitle: meeting.meetingType,
                       status: meeting.status,
                       color: statusColor(meeting.status))
        }
    }

    var body: some View {
        NavigationStack(path: router.path(1)) {
            VStack(spacing: 0) {
                HStack {
                    stats
                    Spacer()
                    Picker("", selection: $mode) {
                        ForEach(MeetingViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                Group {
                    if model.loading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = model.error, model.meetings.isEmpty {
                        VStack(spacing: 14) {
                            ErrorBanner(message: error)
                            Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                            Spacer()
                        }
                        .padding()
                    } else if mode == .calendar {
                        ScrollView {
                            MeetingCalendarView(meetings: calendarMeetings)
                        }
                    } else if model.meetings.isEmpty {
                        ContentUnavailableView("No visits booked", systemImage: "calendar",
                            description: Text("Book a site visit from any project page and it appears here."))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(model.meetings) { meeting in
                                    Button { detail = meeting } label: { card(meeting) }
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
            .background(Color.customerSurface.ignoresSafeArea())
            .portalDestinations()
            .navigationTitle("Site visits")
            .task { await reload() }
            .sheet(item: $detail) { meeting in
                VisitDetailSheet(meeting: meeting) { rating in
                    Task { await model.rate(meeting.id, rating) }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Site visits", isPresented: Binding(get: { model.message != nil },
                                                       set: { if !$0 { model.message = nil } })) {
                Button("OK", role: .cancel) { model.message = nil }
            } message: { Text(model.message ?? "") }
        }
    }

    private func reload() async { await model.load(phone: auth.phone) }

    private var stats: some View {
        HStack(spacing: 12) {
            stat("\(model.meetings.count - model.completed)", "upcoming")
            if model.completed > 0 { stat("\(model.completed)", "visited") }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(Color.dealioTextPrimary)
            Text(label).font(.caption).foregroundStyle(Color.dealioTextSecondary)
        }
    }

    private func card(_ meeting: CustomerMeeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.projectName?.nilIfEmpty ?? "Site visit")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Spacer()
                StatusBadge(text: meeting.status ?? "Pending", color: statusColor(meeting.status))
            }
            Label(meeting.whenText.nilIfEmpty ?? "Waiting on a slot", systemImage: "clock")
                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            if let advisor = meeting.cpName?.nilIfEmpty {
                Text("Arranged by \(advisor)").font(.caption).foregroundStyle(Color.dealioTextSecondary)
            }
            if (meeting.status ?? "").caseInsensitiveCompare("Completed") == .orderedSame {
                Text("Rate your visit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.customerAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

private struct VisitDetailSheet: View {
    let meeting: CustomerMeeting
    let onRate: (Int) -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var rating = 0

    private var contactName: String? { meeting.cpName?.nilIfEmpty ?? meeting.builderName?.nilIfEmpty }
    private var contactPhone: String? { meeting.cpPhone?.nilIfEmpty ?? meeting.builderPhone?.nilIfEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meeting.projectName?.nilIfEmpty ?? "Site visit")
                                .font(.title3.weight(.bold))
                            if let type = meeting.meetingType?.nilIfEmpty {
                                Text(type).font(.footnote).foregroundStyle(Color.dealioTextSecondary)
                            }
                        }
                        Spacer()
                        StatusBadge(text: meeting.status ?? "Pending", color: statusColor(meeting.status))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("When")
                        HStack(spacing: 16) {
                            Label(meeting.confirmedDate ?? meeting.preferredDate ?? "—", systemImage: "calendar")
                            Label((meeting.confirmedTime ?? meeting.preferredTime)?.nilIfEmpty ?? "—",
                                  systemImage: "clock")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        Text(meeting.isConfirmed
                             ? "Confirmed by the builder."
                             : "You asked for this slot — the builder is still confirming it.")
                            .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Where")
                        Text(meeting.whereLine
                             ?? "The builder has not shared a street address. Search the project by name.")
                            .font(.subheadline)
                            .foregroundStyle(meeting.whereLine != nil ? Color.dealioTextPrimary : Color.dealioTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        sheetAction("Open in Maps", "map") {
                            // Falls back to the project name, which is all the web
                            // page has ever had to search on.
                            let project = meeting.projectName?.nilIfEmpty ?? "project"
                            let query = meeting.whereLine.map { "\(project), \($0)" } ?? project
                            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)") {
                                openURL(url)
                            }
                        }
                    }

                    if contactName != nil || contactPhone != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(meeting.cpName?.nilIfEmpty == nil ? "Who to contact" : "Your advisor")
                            Text(contactName ?? "Contact")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dealioTextPrimary)
                            if let phone = contactPhone {
                                Text(phone).font(.footnote).foregroundStyle(Color.dealioTextSecondary)
                                sheetAction("Call \(contactName ?? phone)", "phone") {
                                    if let url = Share.telURL(phone) { openURL(url) }
                                }
                            }
                        }
                    }

                    if let notes = meeting.notes?.trimmedOrNil {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Your note")
                            Text(notes).font(.subheadline).foregroundStyle(Color.dealioTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if (meeting.status ?? "").caseInsensitiveCompare("Completed") == .orderedSame {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Rate your visit")
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        rating = star
                                        onRate(star)
                                    } label: {
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.title3)
                                            .foregroundStyle(star <= rating ? Color.dealioOrange : Color.dealioTextSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.customerSurface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onAppear { rating = meeting.customerRating ?? 0 }
        }
    }

    private func sheetAction(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.customerAccent)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.customerAccent.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
