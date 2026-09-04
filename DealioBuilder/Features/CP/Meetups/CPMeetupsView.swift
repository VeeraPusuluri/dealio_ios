import SwiftUI

/// The partner's meetups.
///
/// Split upcoming from past rather than showing one long list: everything a
/// partner does here is about what has not happened yet, and a finished meetup
/// competing for the same space is noise. Past ones stay reachable because they
/// are the record of who came. Mirrors Android's `CpMeetupsScreen.kt`.

@MainActor
final class CPMeetupsModel: ObservableObject {
    @Published var meetups: [CpMeetup] = []
    @Published var loading = true
    @Published var error: String?
    @Published var message: String?

    private var cpUserId = 0

    var upcoming: [CpMeetup] { meetups.filter { !MeetupTime.isPast($0.date) } }
    var past: [CpMeetup] { meetups.filter { MeetupTime.isPast($0.date) }.reversed() }

    func load(cpUserId: Int, silent: Bool = false) async {
        self.cpUserId = cpUserId
        if !silent { loading = meetups.isEmpty; error = nil }
        do { meetups = try await CPService.meetups(cpUserId: cpUserId) }
        catch { self.error = authMessage(error) }
        loading = false
    }
}

private enum MeetupTab: String, CaseIterable { case upcoming = "Upcoming", past = "Past" }

struct CPMeetupsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPMeetupsModel()
    @State private var tab: MeetupTab = .upcoming
    @State private var composing = false
    @State private var openMeetup: Int?

    private var shown: [CpMeetup] { tab == .upcoming ? model.upcoming : model.past }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.error, model.meetups.isEmpty {
                    VStack(spacing: 14) {
                        ErrorBanner(message: error)
                        Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                } else if model.meetups.isEmpty {
                    ContentUnavailableView {
                        Label("No meetups yet", systemImage: "person.3")
                    } description: {
                        Text("Arrange a site walk-through or an investor evening, pick who to invite, and let customers in your city find it.")
                    } actions: {
                        Button("Create a meetup") { composing = true }.buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 0) {
                        tabStrip
                        if shown.isEmpty {
                            ContentUnavailableView(
                                tab == .upcoming ? "Nothing coming up" : "Nothing in the past",
                                systemImage: tab == .upcoming ? "calendar" : "calendar.badge.minus",
                                description: Text(tab == .upcoming
                                    ? "Your finished meetups are under Past."
                                    : "Meetups move here the day after they happen.")
                            )
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(shown) { meetup in
                                        Button { openMeetup = meetup.id } label: { MeetupCard(meetup: meetup) }
                                            .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 96)
                            }
                            .refreshable { await reload() }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !model.meetups.isEmpty {
                Button { composing = true } label: {
                    Label("New meetup", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(Color.brandTeal, in: Capsule())
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(20)
            }
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Meetups")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .navigationDestination(item: $openMeetup) { id in
            CPMeetupDetailView(meetupId: id)
        }
        .sheet(isPresented: $composing) {
            CPMeetupFormView(meetupId: nil) { Task { await reload() } }
        }
        .alert("Meetups", isPresented: Binding(get: { model.message != nil },
                                               set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func reload() async { await model.load(cpUserId: auth.user?.id ?? 0) }

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(MeetupTab.allCases, id: \.self) { option in
                let selected = tab == option
                let count = option == .upcoming ? model.upcoming.count : model.past.count
                Button { withAnimation(.snappy) { tab = option } } label: {
                    Text(count > 0 ? "\(option.rawValue) · \(count)" : option.rawValue)
                        .font(.footnote.weight(selected ? .bold : .medium))
                        .foregroundStyle(selected ? Color.brandTeal : Color.dealioTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected ? Color(.secondarySystemGroupedBackground) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.dealioNavy.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

/// One meetup, scannable.
///
/// No cover strip: the category chip already carries the colour, and the RSVP
/// counts are the thing a partner opens this list to read. Anything above them
/// costs the vertical space that keeps them above the fold.
private struct MeetupCard: View {
    let meetup: CpMeetup
    @Environment(\.openURL) private var openURL

    var body: some View {
        let category = MeetupCategory.from(meetup.category)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                CategoryChip(category: category)
                Spacer()
                if meetup.isCancelled {
                    Text("Cancelled")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.dealioError)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.dealioError.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else if meetup.isPublic {
                    VisibilityChip(isPublic: true, city: meetup.city)
                }
            }
            .padding(.bottom, 10)

            Text(meetup.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dealioTextPrimary)
                .lineLimit(2)
                .padding(.bottom, 10)

            MeetupDetailLine(icon: "calendar",
                             text: MeetupTime.when(date: meetup.date, time: meetup.time), lineLimit: 1)
            if MeetupMode.from(meetup.mode) != .online, !meetup.location.isEmpty {
                MeetupDetailLine(icon: "mappin.and.ellipse", text: meetup.location, lineLimit: 1)
                    .padding(.top, 5)
            }

            RsvpSummary(going: meetup.counts.going, maybe: meetup.counts.maybe,
                        noReply: meetup.counts.noReply)
                .padding(.top, 12)

            Button {
                if let url = Share.whatsAppURL(phone: nil, text: meetupShareText(meetup)) { openURL(url) }
            } label: {
                Label("Share invite", systemImage: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTeal)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(Color.brandTeal.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

/// The invite as a partner would write it out — used for WhatsApp and the share
/// sheet, so both say exactly the same thing.
func meetupShareText(_ meetup: CpMeetup) -> String {
    var lines = [meetup.title, ""]
    lines.append("When: \(MeetupTime.dayLabel(meetup.date)), \(meetup.time)")
    if MeetupMode.from(meetup.mode) != .online, !meetup.location.isEmpty {
        lines.append("Where: \(meetup.location)")
    }
    if let description = meetup.description?.trimmedOrNil {
        lines.append("")
        lines.append(description)
    }
    if meetup.isCancelled {
        lines.append("")
        lines.append("This meetup has been cancelled." + (meetup.cancelReason.map { " \($0)" } ?? ""))
    }
    if let maps = meetup.mapsLink?.trimmedOrNil {
        lines.append("")
        lines.append(maps)
    }
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}
