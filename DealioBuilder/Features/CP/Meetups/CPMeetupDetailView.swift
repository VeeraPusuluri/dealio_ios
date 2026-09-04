import SwiftUI

/// One meetup, as the organiser runs it.
///
/// The page the invite is built from and the register the day is worked off:
/// who is coming, who has not answered, and the four things a partner does about
/// it — invite more, record a reply, share, cancel. Mirrors Android's
/// `CpMeetupDetailScreen.kt`.

@MainActor
final class CPMeetupDetailModel: ObservableObject {
    @Published var meetup: CpMeetup?
    @Published var people = InvitableResponse()
    @Published var loading = true
    @Published var busy = false
    @Published var error: String?
    @Published var message: String?
    @Published var deleted = false

    private var cpUserId = 0
    private var meetupId = 0

    func load(cpUserId: Int, meetupId: Int, silent: Bool = false) async {
        self.cpUserId = cpUserId
        self.meetupId = meetupId
        if !silent { loading = meetup == nil; error = nil }
        do {
            meetup = try await CPService.meetup(cpUserId: cpUserId, meetupId: meetupId)
            // Loaded alongside so "Invite more" opens instantly; a failure here
            // costs a picker, not the page.
            people = (try? await CPService.invitable(cpUserId: cpUserId)) ?? InvitableResponse()
        } catch { self.error = authMessage(error) }
        loading = false
    }

    private func refresh(_ success: String?) async {
        message = success
        await load(cpUserId: cpUserId, meetupId: meetupId, silent: true)
    }

    func invite(_ people: [CpMeetupInviteePayload]) async {
        guard !people.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            try await CPService.addInvitees(cpUserId: cpUserId, meetupId: meetupId, people)
            await refresh("Invited \(people.count) \(people.count == 1 ? "person" : "people")")
        } catch { message = authMessage(error) }
    }

    func setRSVP(inviteeId: Int, rsvp: Rsvp) async {
        busy = true
        defer { busy = false }
        do {
            try await CPService.setInviteeRSVP(cpUserId: cpUserId, meetupId: meetupId,
                                               inviteeId: inviteeId, rsvp: rsvp.rawValue, guests: nil)
            await refresh(nil)
        } catch { message = authMessage(error) }
    }

    func checkIn(inviteeId: Int) async {
        busy = true
        defer { busy = false }
        // Checking someone in is recorded as "they came", which is what the
        // backend derives the attendance count from.
        do {
            try await CPService.setInviteeRSVP(cpUserId: cpUserId, meetupId: meetupId,
                                               inviteeId: inviteeId, rsvp: Rsvp.going.rawValue, guests: nil)
            await refresh("Checked in")
        } catch { message = authMessage(error) }
    }

    func removeInvitee(_ inviteeId: Int) async {
        busy = true
        defer { busy = false }
        do {
            try await CPService.removeInvitee(cpUserId: cpUserId, meetupId: meetupId, inviteeId: inviteeId)
            await refresh("Removed from the list")
        } catch { message = authMessage(error) }
    }

    func cancel(reason: String?) async {
        busy = true
        defer { busy = false }
        do {
            try await CPService.cancelMeetup(cpUserId: cpUserId, meetupId: meetupId, reason: reason)
            await refresh("Meetup cancelled — everyone invited has been told")
        } catch { message = authMessage(error) }
    }

    func delete() async {
        busy = true
        defer { busy = false }
        do {
            try await CPService.deleteMeetup(cpUserId: cpUserId, meetupId: meetupId)
            deleted = true
        } catch { message = authMessage(error) }
    }
}

struct CPMeetupDetailView: View {
    let meetupId: Int

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CPMeetupDetailModel()

    @State private var inviting = false
    @State private var cancelling = false
    @State private var confirmDelete = false
    @State private var editing = false
    @State private var addingToCalendar = false
    @State private var cancelReason = ""
    @State private var rsvpTarget: CpMeetupInvitee?

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let meetup = model.meetup {
                content(meetup)
            } else {
                VStack(spacing: 14) {
                    ErrorBanner(message: model.error ?? "Meetup not found")
                    Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Meetup")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .onChange(of: model.deleted) { _, gone in if gone { dismiss() } }
        .sheet(isPresented: $inviting) {
            InviteMoreSheet(people: model.people,
                            alreadyInvited: Set((model.meetup?.invitees ?? []).map { normalised($0.phone) }),
                            saving: model.busy) { picked in
                inviting = false
                Task { await model.invite(picked) }
            }
        }
        .sheet(isPresented: $editing) {
            CPMeetupFormView(meetupId: meetupId) { Task { await reload() } }
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
        .alert("Are they coming?", isPresented: Binding(get: { rsvpTarget != nil },
                                                        set: { if !$0 { rsvpTarget = nil } })) {
            ForEach([Rsvp.going, .maybe, .declined, .invited]) { option in
                Button(option.label) {
                    if let target = rsvpTarget { Task { await model.setRSVP(inviteeId: target.id, rsvp: option) } }
                    rsvpTarget = nil
                }
            }
            Button("Remove from list", role: .destructive) {
                if let target = rsvpTarget { Task { await model.removeInvitee(target.id) } }
                rsvpTarget = nil
            }
            Button("Close", role: .cancel) { rsvpTarget = nil }
        } message: {
            Text(rsvpTarget?.name ?? "")
        }
        .alert("Cancel this meetup?", isPresented: $cancelling) {
            TextField("Why (optional)", text: $cancelReason)
            Button("Cancel meetup", role: .destructive) {
                let reason = cancelReason.trimmedOrNil
                cancelReason = ""
                Task { await model.cancel(reason: reason) }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Everyone invited is told it is off. The event stays on the list so they can see why.")
        }
        .alert("Delete this meetup?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await model.delete() } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("It disappears for everyone, including people who said they were going. If it is off rather than gone, cancel it instead — that tells them why.")
        }
        .alert("Meetup", isPresented: Binding(get: { model.message != nil },
                                              set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func reload() async {
        await model.load(cpUserId: auth.user?.id ?? 0, meetupId: meetupId)
    }

    private func normalised(_ phone: String) -> String { String(phone.filter(\.isNumber).suffix(10)) }

    @ViewBuilder
    private func content(_ meetup: CpMeetup) -> some View {
        let category = MeetupCategory.from(meetup.category)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The organiser sees the same cover the customer will, so this
                // page doubles as a check on what was uploaded.
                MeetupHero(category: category, height: 150, coverImage: meetup.coverImage)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        CategoryChip(category: category)
                        VisibilityChip(isPublic: meetup.isPublic, city: meetup.city)
                    }

                    Text(meetup.title)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if meetup.isCancelled { cancelledBanner(meetup.cancelReason) }

                    whenAndWhere(meetup)
                    if meetup.description?.trimmedOrNil != nil || !meetup.topics.isEmpty { about(meetup) }
                    if !meetup.photos.isEmpty { photos(meetup) }
                    whosComing(meetup)
                    if let notes = meetup.notes?.trimmedOrNil { privateNote(notes) }
                    actions(meetup)
                }
                .padding(16)
            }
        }
        .refreshable { await reload() }
    }

    private func cancelledBanner(_ reason: String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(Color.dealioError)
            VStack(alignment: .leading, spacing: 2) {
                Text("This meetup is cancelled")
                    .font(.footnote.weight(.bold)).foregroundStyle(Color.dealioError)
                if let reason, !reason.isEmpty {
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

    private func whenAndWhere(_ meetup: CpMeetup) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            MeetupDetailLine(icon: "calendar", text: MeetupTime.fullDate(meetup.date))
            MeetupDetailLine(icon: "clock", text: meetup.time)
            if MeetupMode.from(meetup.mode) != .online, !meetup.location.isEmpty {
                MeetupDetailLine(icon: "mappin.and.ellipse", text: meetup.location, lineLimit: 3)
            }
            if let link = meetup.onlineLink?.trimmedOrNil {
                MeetupDetailLine(icon: "video", text: link, lineLimit: 1)
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

    private func about(_ meetup: CpMeetup) -> some View {
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
                            .foregroundStyle(Color.brandTeal)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color.brandTeal.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func photos(_ meetup: CpMeetup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Photos")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(meetup.photos, id: \.self) { photo in
                        AsyncImage(url: AppConfig.resolveAssetURL(photo)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.dealioFieldFill)
                        }
                        .frame(width: 120, height: 90)
                        .clipShape(RoundedCornerShape12())
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func whosComing(_ meetup: CpMeetup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Who's coming")
                Spacer()
                if let capacity = meetup.capacity {
                    Text("\(meetup.counts.goingHeads)/\(capacity)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(meetup.isFull ? Color.dealioOrange : Color.dealioTextSecondary)
                }
            }
            RsvpSummary(going: meetup.counts.going, maybe: meetup.counts.maybe,
                        noReply: meetup.counts.noReply, font: .footnote)

            ForEach(meetup.invitees) { invitee in
                inviteeRow(invitee, enabled: !model.busy && !meetup.isCancelled)
            }

            softAction("Invite more people", "person.crop.circle.badge.plus",
                       enabled: !meetup.isCancelled) { inviting = true }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    /// One person on the list.
    ///
    /// Tapping the row cycles their answer rather than opening a menu: a partner
    /// working down a list of replies from WhatsApp does this a dozen times in a
    /// row, and a two-tap menu each time is the difference between doing it and
    /// not.
    private func inviteeRow(_ invitee: CpMeetupInvitee, enabled: Bool) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(Color.dealioMist)
                Text(initials(invitee.name))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dealioTextSecondary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(invitee.name)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .lineLimit(1)
                    if invitee.foundItThemselves {
                        Text("Found it")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.green.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    if invitee.isCheckedIn {
                        Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.green)
                    }
                }
                Text(invitee.guests > 0 ? "\(invitee.phone) · +\(invitee.guests)" : invitee.phone)
                    .font(.caption2)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            RsvpPill(rsvp: Rsvp.from(invitee.rsvp))
            Button {
                if let url = Share.telURL(invitee.phone) { openURL(url) }
            } label: {
                Image(systemName: "phone").foregroundStyle(Color.brandTeal).frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { if enabled { rsvpTarget = invitee } }
    }

    private func privateNote(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Only you can see this", systemImage: "lock")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.dealioTextSecondary)
            Text(note)
                .font(.footnote)
                .foregroundStyle(Color.dealioTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dealioFieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func actions(_ meetup: CpMeetup) -> some View {
        VStack(spacing: 10) {
            Button {
                if let url = Share.whatsAppURL(phone: nil, text: meetupShareText(meetup)) { openURL(url) }
            } label: {
                Label("Share invite", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.brandTeal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                outlineAction("Edit", "pencil", .brandTeal) { editing = true }
                if !meetup.isCancelled {
                    outlineAction("Cancel", "calendar.badge.minus", .orange) { cancelling = true }
                }
                outlineAction("Delete", "trash", .dealioError) { confirmDelete = true }
            }
        }
        .padding(.top, 6)
    }

    private func softAction(_ label: String, _ icon: String, enabled: Bool = true,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandTeal)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Color.brandTeal.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    private func outlineAction(_ label: String, _ icon: String, _ tint: Color,
                               _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        let letters = String(parts).uppercased()
        return letters.isEmpty ? "?" : letters
    }
}

/// A 12pt continuous corner, used where a `clipShape` reads better than a
/// background modifier (an `AsyncImage` fills its frame before it is clipped).
struct RoundedCornerShape12: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: 12, style: .continuous)
    }
}

// MARK: - Invite more

/// Adding people after the fact — the same picker the form uses.
struct InviteMoreSheet: View {
    let people: InvitableResponse
    let alreadyInvited: Set<String>
    let saving: Bool
    let onInvite: ([CpMeetupInviteePayload]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<String> = []
    @State private var query = ""
    @State private var manualName = ""
    @State private var manualPhone = ""
    @State private var manual: [CpMeetupInviteePayload] = []

    private var candidates: [CpMeetupInviteePayload] {
        let fromContacts = people.contacts.map {
            CpMeetupInviteePayload(contactId: $0.id, name: $0.name, phone: $0.phone, email: $0.email)
        }
        let fromCustomers = people.customers.map {
            CpMeetupInviteePayload(contactId: nil, name: $0.name, phone: $0.phone, email: $0.email)
        }
        // Somebody in both lists is one person; the contact entry wins because it
        // carries the id that links the invite back to the CRM row.
        var seen = Set<String>()
        var result: [CpMeetupInviteePayload] = []
        for person in fromContacts + fromCustomers where !person.id.isEmpty {
            guard !seen.contains(person.id), !alreadyInvited.contains(person.id) else { continue }
            seen.insert(person.id)
            result.append(person)
        }
        guard let needle = query.trimmedOrNil else { return result }
        return result.filter {
            $0.name.localizedCaseInsensitiveContains(needle) || $0.phone.contains(needle)
        }
    }

    private var chosen: [CpMeetupInviteePayload] {
        candidates.filter { picked.contains($0.id) } + manual
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Add someone not on your list") {
                    TextField("Name", text: $manualName)
                    TextField("Phone", text: $manualPhone).keyboardType(.phonePad)
                    Button("Add to invite list") {
                        let digits = manualPhone.filter(\.isNumber)
                        guard let name = manualName.trimmedOrNil, digits.count >= 6 else { return }
                        manual.append(CpMeetupInviteePayload(contactId: nil, name: name,
                                                             phone: digits, email: nil))
                        manualName = ""; manualPhone = ""
                    }
                    .disabled(manualName.trimmedOrNil == nil || manualPhone.filter(\.isNumber).count < 6)
                    ForEach(manual) { person in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brandTeal)
                            Text(person.name)
                            Spacer()
                            Button("Remove") { manual.removeAll { $0.id == person.id } }
                                .font(.caption).foregroundStyle(Color.dealioError)
                        }
                    }
                }

                Section("From your contacts and buyers") {
                    if candidates.isEmpty {
                        Text("Everyone available is already on the list.")
                            .font(.footnote).foregroundStyle(Color.dealioTextSecondary)
                    }
                    ForEach(candidates) { person in
                        Button {
                            if picked.contains(person.id) { picked.remove(person.id) }
                            else { picked.insert(person.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: picked.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(picked.contains(person.id) ? Color.brandTeal : Color.dealioTextSecondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(person.name).font(.subheadline)
                                    Text(person.phone).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search people")
            .navigationTitle("Invite people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(chosen.isEmpty ? "Invite" : "Invite \(chosen.count)") { onInvite(chosen) }
                        .disabled(chosen.isEmpty || saving)
                }
            }
        }
    }
}
