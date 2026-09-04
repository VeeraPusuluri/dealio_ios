import SwiftUI

/// Meetups, as a customer sees them.
///
/// Ordered by how much each one is asking of this person: invitations awaiting a
/// reply, then what they have already said yes to, then everything else on in
/// their city. Someone who was personally asked should never have to scroll past
/// a listing to find that out. Mirrors Android's `CustomerMeetupsScreen.kt`.

@MainActor
final class CustomerMeetupsModel: ObservableObject {
    @Published var meetups: [CustomerMeetup] = []
    /// The city the list is showing, as the server resolved it.
    @Published var city: String?
    @Published var category: MeetupCategory?
    @Published var loading = true
    @Published var error: String?
    @Published var busyId: Int?
    @Published var message: String?

    /// Asked personally, and still owe an answer. These come first everywhere —
    /// someone waiting on this customer specifically outranks a listing.
    var awaitingReply: [CustomerMeetup] { meetups.filter { $0.awaitingReply && !$0.isCancelled } }
    /// Answered yes. Their plans.
    var going: [CustomerMeetup] { meetups.filter(\.isGoing) }
    /// Everything else on offer — found by browsing, not by being asked.
    var nearby: [CustomerMeetup] { meetups.filter { !$0.awaitingReply && !$0.isGoing } }

    func load(silent: Bool = false) async {
        if !silent { loading = meetups.isEmpty; error = nil }
        do {
            let feed = try await CustomerService.meetups(category: category?.rawValue)
            meetups = feed.meetups
            city = feed.city
        } catch { self.error = authMessage(error) }
        loading = false
    }

    func setCategory(_ category: MeetupCategory?) async {
        self.category = category
        await load(silent: true)
    }

    func rsvp(_ meetupId: Int, _ answer: Rsvp, guests: Int = 0) async {
        busyId = meetupId
        defer { busyId = nil }
        do {
            let updated = try await CustomerService.rsvpToMeetup(meetupId, rsvp: answer, guests: guests)
            // Swap the one row rather than refetching: the list keeps its scroll
            // position and the change lands immediately.
            if let index = meetups.firstIndex(where: { $0.id == meetupId }) { meetups[index] = updated }
            switch answer {
            case .going: message = "You're going"
            case .maybe: message = "Marked as maybe"
            default: message = "Thanks for letting them know"
            }
        } catch { message = authMessage(error) }
    }
}

struct CustomerMeetupsView: View {
    @StateObject private var model = CustomerMeetupsModel()
    @State private var openMeetup: Int?

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.meetups.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await model.load() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        categoryFilter

                        if model.meetups.isEmpty {
                            ContentUnavailableView("No meetups yet", systemImage: "person.3",
                                description: Text("Site visits and open houses near you will show up here. Set your city in your profile to see more."))
                                .padding(.top, 20)
                        }

                        section("You're invited", model.awaitingReply)
                        section("You're going", model.going)
                        section(model.city.map { "On in \($0)" } ?? "Near you", model.nearby)
                    }
                    .padding(.bottom, 28)
                }
                .refreshable { await model.load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("Meetups")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .navigationDestination(item: $openMeetup) { id in
            CustomerMeetupDetailView(meetupId: id)
        }
        .alert("Meetups", isPresented: Binding(get: { model.message != nil },
                                               set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [CustomerMeetup]) -> some View {
        if !items.isEmpty {
            SectionLabel(title)
                .padding(.horizontal, 16).padding(.vertical, 4)
            ForEach(items) { meetup in
                Button { openMeetup = meetup.id } label: {
                    CustomerMeetupCard(meetup: meetup)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill("All", on: model.category == nil, tint: .customerAccent) {
                    Task { await model.setCategory(nil) }
                }
                ForEach(MeetupCategory.allCases) { option in
                    filterPill(option.label, on: model.category == option, tint: option.tint) {
                        Task { await model.setCategory(model.category == option ? nil : option) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func filterPill(_ label: String, on: Bool, tint: Color,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(on ? .semibold : .regular))
                .foregroundStyle(on ? .white : Color.dealioTextPrimary)
                .lineLimit(1)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(on ? tint : Color(.secondarySystemGroupedBackground), in: Capsule())
                .overlay(Capsule().strokeBorder(on ? tint : Color.dealioCardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// One meetup on a customer's list.
///
/// Leads with the photograph when there is one. A customer is browsing rather
/// than working through a list, and the picture is what makes them stop — the
/// text below it is what makes them tap. Where no cover was uploaded the strip
/// falls back to the category wash, which keeps the list on one rhythm instead
/// of alternating between tall cards and short ones.
struct CustomerMeetupCard: View {
    let meetup: CustomerMeetup

    var body: some View {
        let category = MeetupCategory.from(meetup.category)
        VStack(alignment: .leading, spacing: 0) {
            MeetupHero(category: category, height: 132, coverImage: meetup.coverImage,
                       scrim: meetup.coverImage?.trimmedOrNil != nil) {
                VStack {
                    HStack {
                        Spacer()
                        if meetup.isCancelled { badge("Cancelled", .dealioError) }
                        else if meetup.isGoing { badge("You're going", .green) }
                        else if meetup.awaitingReply { badge("Invited", .customerAccent) }
                    }
                    Spacer()
                }
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 10) {
                CategoryChip(category: category)
                Text(meetup.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(2)
                VStack(alignment: .leading, spacing: 5) {
                    MeetupDetailLine(icon: "calendar",
                                     text: MeetupTime.when(date: meetup.date, time: meetup.time), lineLimit: 1)
                    if MeetupMode.from(meetup.mode) != .online, !meetup.location.isEmpty {
                        MeetupDetailLine(icon: "mappin.and.ellipse", text: meetup.location, lineLimit: 1)
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "person.2").font(.caption2)
                    Text(meetup.goingCount == 0 ? "Be the first to go" : "\(meetup.goingCount) going")
                        .font(.caption.weight(.medium))
                    Spacer()
                    if !meetup.hostName.isEmpty {
                        Text("by \(meetup.hostName)").font(.caption2).lineLimit(1)
                    }
                }
                .foregroundStyle(Color.dealioTextSecondary)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.dealioCardBorder.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, y: 5)
    }

    /// A status flag, filled solid — a tinted wash reads as mud over a
    /// photograph, and this is the one label that has to survive what is behind it.
    private func badge(_ label: String, _ tint: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
