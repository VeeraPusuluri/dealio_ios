import SwiftUI

/// One meetup, as a customer decides whether to go.
///
/// The whole page is arranged around one question, so the answer sits in a bar
/// pinned to the bottom rather than somewhere down the scroll: going, maybe, or
/// can't go — plus how many people they are bringing. Mirrors Android's
/// `CustomerMeetupDetailScreen.kt`.

@MainActor
final class CustomerMeetupDetailModel: ObservableObject {
    @Published var meetup: CustomerMeetup?
    @Published var loading = true
    @Published var busy = false
    @Published var error: String?
    @Published var message: String?

    private var meetupId = 0

    func load(meetupId: Int, silent: Bool = false) async {
        self.meetupId = meetupId
        if !silent { loading = meetup == nil; error = nil }
        do { meetup = try await CustomerService.meetup(meetupId) }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func rsvp(_ answer: Rsvp, guests: Int) async {
        busy = true
        defer { busy = false }
        do {
            meetup = try await CustomerService.rsvpToMeetup(meetupId, rsvp: answer, guests: guests)
            switch answer {
            case .going: message = "You're going — the organiser has been told."
            case .maybe: message = "Marked as maybe."
            default: message = "Thanks for letting them know."
            }
        } catch { message = authMessage(error) }
    }
}

struct CustomerMeetupDetailView: View {
    let meetupId: Int

    @Environment(\.openURL) private var openURL
    @StateObject private var model = CustomerMeetupDetailModel()
    @State private var guests = 0
    @State private var addingToCalendar = false

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let meetup = model.meetup {
                VStack(spacing: 0) {
                    content(meetup)
                    if !meetup.isCancelled { answerBar(meetup) }
                }
            } else {
                VStack(spacing: 14) {
                    ErrorBanner(message: model.error ?? "Meetup not found")
                    Button("Try again") { Task { await model.load(meetupId: meetupId) } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("Meetup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load(meetupId: meetupId)
            guests = model.meetup?.myGuests ?? 0
        }
        .sheet(isPresented: $addingToCalendar) {
            if let meetup = model.meetup,
               let start = MeetupTime.dateTime(date: meetup.date, time: meetup.time) {
                MeetupCalendarSheet(title: meetup.title, location: meetup.location,
                                    notes: meetup.description, start: start) {
                    addingToCalendar = false
                }
                .ignoresSafeArea()
            }
        }
        .alert("Meetup", isPresented: Binding(get: { model.message != nil },
                                              set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    @ViewBuilder
    private func content(_ meetup: CustomerMeetup) -> some View {
        let category = MeetupCategory.from(meetup.category)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MeetupHero(category: category, height: 180, coverImage: meetup.coverImage,
                           scrim: meetup.coverImage?.trimmedOrNil != nil)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        CategoryChip(category: category)
                        if meetup.isGoing { RsvpPill(rsvp: .going) }
                        else if meetup.awaitingReply { RsvpPill(rsvp: .invited) }
                    }

                    Text(meetup.title)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if meetup.isCancelled {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .foregroundStyle(Color.dealioError)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("This meetup was cancelled")
                                    .font(.footnote.weight(.bold)).foregroundStyle(Color.dealioError)
                                if let reason = meetup.cancelReason?.trimmedOrNil {
                                    Text(reason).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.dealioError.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    whenAndWhere(meetup)
                    if meetup.description?.trimmedOrNil != nil || !meetup.topics.isEmpty { about(meetup) }
                    if !meetup.photos.isEmpty { photos(meetup) }
                    whoElse(meetup)
                    host(meetup)
                }
                .padding(16)
                .padding(.bottom, 12)
            }
        }
        .refreshable { await model.load(meetupId: meetupId, silent: true) }
    }

    private func whenAndWhere(_ meetup: CustomerMeetup) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            MeetupDetailLine(icon: "calendar", text: MeetupTime.fullDate(meetup.date))
            MeetupDetailLine(icon: "clock", text: meetup.time)
            if MeetupMode.from(meetup.mode) != .online, !meetup.location.isEmpty {
                MeetupDetailLine(icon: "mappin.and.ellipse", text: meetup.location, lineLimit: 3)
            }
            // The joining link is only sent once the buyer is going — the server
            // withholds it from everyone else, so its presence is the permission.
            if let link = meetup.onlineLink?.trimmedOrNil {
                Button {
                    if let url = URL(string: link) { openURL(url) }
                } label: {
                    MeetupDetailLine(icon: "video", text: link, lineLimit: 1)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                if let maps = meetup.mapsLink?.trimmedOrNil, let url = URL(string: maps) {
                    softAction("Open in Maps", "mappin.and.ellipse") { openURL(url) }
                }
                softAction("Add to calendar", "calendar.badge.plus") { addingToCalendar = true }
            }
            .padding(.top, 5)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func about(_ meetup: CustomerMeetup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("About")
            if let description = meetup.description?.trimmedOrNil {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !meetup.topics.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(meetup.topics, id: \.self) { topic in
                        Text(topic)
                            .font(.caption)
                            .foregroundStyle(Color.customerAccent)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color.customerAccent.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func photos(_ meetup: CustomerMeetup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("The place")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(meetup.photos, id: \.self) { photo in
                        AsyncImage(url: AppConfig.resolveAssetURL(photo)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.dealioFieldFill)
                        }
                        .frame(width: 150, height: 110)
                        .clipShape(RoundedCornerShape12())
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func whoElse(_ meetup: CustomerMeetup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Who's going")
                Spacer()
                if let capacity = meetup.capacity {
                    Text("\(meetup.goingCount)/\(capacity)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(meetup.isFull ? Color.dealioOrange : Color.dealioTextSecondary)
                }
            }
            Text(meetup.goingCount == 0 ? "Be the first to say yes." : "\(meetup.goingCount) going")
                .font(.footnote)
                .foregroundStyle(Color.dealioTextPrimary)
            if !meetup.goingNames.isEmpty {
                Text(meetup.goingNames.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if meetup.isFull && !meetup.isGoing {
                Text("This one is full. You can still mark yourself as maybe.")
                    .font(.caption)
                    .foregroundStyle(Color.dealioStatusAmber)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func host(_ meetup: CustomerMeetup) -> some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: meetup.hostName.nilIfEmpty ?? "Host", tint: .customerAccent, size: 42)
            VStack(alignment: .leading, spacing: 1) {
                Text(meetup.hostName.nilIfEmpty ?? "Your advisor")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text([meetup.hostTier, "Hosting this meetup"].compactMap { $0?.nilIfEmpty }
                        .joined(separator: " · "))
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            }
            Spacer()
            // Only sent when this customer was personally invited, so its
            // presence is the permission to ring them.
            if let phone = meetup.hostPhone?.trimmedOrNil {
                Button { if let url = Share.telURL(phone) { openURL(url) } } label: {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(Color.customerAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.customerAccent.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func answerBar(_ meetup: CustomerMeetup) -> some View {
        VStack(spacing: 8) {
            if meetup.isGoing {
                Stepper("Bringing \(guests) guest\(guests == 1 ? "" : "s")", value: $guests, in: 0...10)
                    .font(.footnote)
                    .onChange(of: guests) { _, value in
                        Task { await model.rsvp(.going, guests: value) }
                    }
            }
            HStack(spacing: 8) {
                answerButton(.going, meetup)
                answerButton(.maybe, meetup)
                answerButton(.declined, meetup)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.bar)
    }

    private func answerButton(_ answer: Rsvp, _ meetup: CustomerMeetup) -> some View {
        let selected = Rsvp.from(meetup.myRsvp) == answer
        return Button {
            Task { await model.rsvp(answer, guests: answer == .going ? guests : 0) }
        } label: {
            Text(answer.label)
                .font(.footnote.weight(.bold))
                .foregroundStyle(selected ? .white : answer.tint)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(selected ? answer.tint : answer.tint.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.busy)
    }

    private func softAction(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.customerAccent)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Color.customerAccent.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
