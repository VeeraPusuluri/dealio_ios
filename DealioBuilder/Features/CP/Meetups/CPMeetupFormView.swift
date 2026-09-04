import SwiftUI
import PhotosUI

/// Creating or editing a meetup.
///
/// One screen for both, so the two cannot drift apart — an id means edit. Mirrors
/// Android's `CpMeetupFormScreen.kt`.

@MainActor
final class CPMeetupFormModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var category: MeetupCategory = .siteVisit
    @Published var mode: MeetupMode = .inPerson
    @Published var date = Date()
    @Published var time = Date()
    @Published var location = ""
    @Published var city = ""
    @Published var mapsLink = ""
    @Published var onlineLink = ""
    @Published var notes = ""
    @Published var isPublic = true
    @Published var capacity = ""
    @Published var topics: [String] = []
    @Published var coverImage: String?
    @Published var photos: [String] = []

    @Published var people = InvitableResponse()
    @Published var picked: Set<String> = []
    @Published var manual: [CpMeetupInviteePayload] = []

    @Published var loading = false
    @Published var saving = false
    @Published var uploading = false
    @Published var message: String?
    @Published var saved = false

    private var cpUserId = 0
    private var meetupId: Int?

    var isEditing: Bool { meetupId != nil }
    var canSave: Bool {
        title.trimmedOrNil != nil
            && (mode == .online || location.trimmedOrNil != nil)
            && !saving
    }

    func prepare(cpUserId: Int, meetupId: Int?) async {
        self.cpUserId = cpUserId
        self.meetupId = meetupId
        loading = meetupId != nil
        // The invite picker is only offered on a new meetup — an existing one
        // adds people from its own page, where the current list is visible.
        if meetupId == nil {
            people = (try? await CPService.invitable(cpUserId: cpUserId)) ?? InvitableResponse()
        }
        if let meetupId {
            do {
                let meetup = try await CPService.meetup(cpUserId: cpUserId, meetupId: meetupId)
                apply(meetup)
            } catch { message = authMessage(error) }
        }
        loading = false
    }

    private func apply(_ meetup: CpMeetup) {
        title = meetup.title
        description = meetup.description ?? ""
        category = MeetupCategory.from(meetup.category)
        mode = MeetupMode.from(meetup.mode)
        if let parsed = MeetupTime.dateTime(date: meetup.date, time: meetup.time) {
            date = parsed
            time = parsed
        }
        location = meetup.location
        city = meetup.city ?? ""
        mapsLink = meetup.mapsLink ?? ""
        onlineLink = meetup.onlineLink ?? ""
        notes = meetup.notes ?? ""
        isPublic = meetup.isPublic
        capacity = meetup.capacity.map(String.init) ?? ""
        topics = meetup.topics
        coverImage = meetup.coverImage
        photos = meetup.photos
    }

    func addTopic(_ topic: String) {
        guard let trimmed = topic.trimmedOrNil, !topics.contains(trimmed) else { return }
        topics.append(trimmed)
    }

    func upload(_ data: Data, asCover: Bool) async {
        uploading = true
        defer { uploading = false }
        do {
            let result = try await CPService.uploadMeetupPhoto(
                cpUserId: cpUserId, data: data,
                fileName: "meetup-\(Int(Date().timeIntervalSince1970)).jpg",
                mimeType: "image/jpeg"
            )
            guard !result.url.isEmpty else { return }
            if asCover { coverImage = result.url } else { photos.append(result.url) }
        } catch { message = authMessage(error) }
    }

    var invitees: [CpMeetupInviteePayload] {
        let fromContacts = people.contacts.map {
            CpMeetupInviteePayload(contactId: $0.id, name: $0.name, phone: $0.phone, email: $0.email)
        }
        let fromCustomers = people.customers.map {
            CpMeetupInviteePayload(contactId: nil, name: $0.name, phone: $0.phone, email: $0.email)
        }
        var seen = Set<String>()
        var result: [CpMeetupInviteePayload] = []
        for person in fromContacts + fromCustomers where picked.contains(person.id) {
            guard !seen.contains(person.id) else { continue }
            seen.insert(person.id)
            result.append(person)
        }
        return result + manual
    }

    func save() async {
        guard canSave else { return }
        saving = true
        defer { saving = false }
        let wireDate = MeetupTime.wireDate(date)
        let wireTime = MeetupTime.wireTime(time)
        do {
            if let meetupId {
                // An edit sends the whole form: the server treats a nil field as
                // "leave alone", and every field on this screen is on the form.
                _ = try await CPService.updateMeetup(cpUserId: cpUserId, meetupId: meetupId, .init(
                    title: title.trimmedOrNil, description: description.trimmedOrNil,
                    category: category.rawValue, coverImage: coverImage ?? "",
                    photos: photos, topics: topics,
                    location: location.trimmedOrNil, city: city.trimmedOrNil,
                    mapsLink: mapsLink.trimmedOrNil, mode: mode.rawValue,
                    onlineLink: onlineLink.trimmedOrNil, date: wireDate, time: wireTime,
                    notes: notes.trimmedOrNil, visibility: isPublic ? "PUBLIC" : "PRIVATE",
                    capacity: Int(capacity.filter(\.isNumber))
                ))
            } else {
                _ = try await CPService.createMeetup(cpUserId: cpUserId, .init(
                    title: title.trimmingCharacters(in: .whitespaces),
                    location: location.trimmingCharacters(in: .whitespaces),
                    date: wireDate, time: wireTime,
                    description: description.trimmedOrNil,
                    category: category.rawValue, coverImage: coverImage,
                    photos: photos, topics: topics, city: city.trimmedOrNil,
                    mapsLink: mapsLink.trimmedOrNil, mode: mode.rawValue,
                    onlineLink: onlineLink.trimmedOrNil, notes: notes.trimmedOrNil,
                    visibility: isPublic ? "PUBLIC" : "PRIVATE",
                    capacity: Int(capacity.filter(\.isNumber)),
                    invitees: invitees
                ))
            }
            saved = true
        } catch { message = authMessage(error) }
    }
}

struct CPMeetupFormView: View {
    let meetupId: Int?
    var onSaved: () -> Void = {}

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CPMeetupFormModel()

    @State private var coverPick: PhotosPickerItem?
    @State private var photoPick: PhotosPickerItem?
    @State private var topicDraft = ""
    @State private var manualName = ""
    @State private var manualPhone = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Form {
                        coverSection
                        whatSection
                        whenSection
                        whereSection
                        visibilitySection
                        if !model.isEditing { inviteSection }
                        notesSection
                    }
                }
            }
            .navigationTitle(model.isEditing ? "Edit meetup" : "New meetup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.saving ? "Saving…" : "Save") { Task { await model.save() } }
                        .disabled(!model.canSave)
                }
            }
            .task { await model.prepare(cpUserId: auth.user?.id ?? 0, meetupId: meetupId) }
            .onChange(of: model.saved) { _, done in
                if done { onSaved(); dismiss() }
            }
            .onChange(of: coverPick) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        await model.upload(data, asCover: true)
                    }
                    coverPick = nil
                }
            }
            .onChange(of: photoPick) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        await model.upload(data, asCover: false)
                    }
                    photoPick = nil
                }
            }
            .alert("Meetup", isPresented: Binding(get: { model.message != nil },
                                                  set: { if !$0 { model.message = nil } })) {
                Button("OK", role: .cancel) { model.message = nil }
            } message: { Text(model.message ?? "") }
        }
    }

    // MARK: Sections

    private var coverSection: some View {
        Section("Cover photo") {
            MeetupHero(category: model.category, height: 120, coverImage: model.coverImage)
                .clipShape(RoundedCornerShape12())
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            HStack {
                PhotosPicker(selection: $coverPick, matching: .images) {
                    Label(model.coverImage == nil ? "Add a cover" : "Replace cover", systemImage: "photo")
                }
                if model.coverImage != nil {
                    Spacer()
                    Button("Remove", role: .destructive) { model.coverImage = nil }.font(.footnote)
                }
                if model.uploading { ProgressView().padding(.leading, 8) }
            }
        }
    }

    private var whatSection: some View {
        Section("What is it") {
            TextField("e.g. Nature County site walk-through", text: $model.title)
            TextField("What will happen, and why someone should come",
                      text: $model.description, axis: .vertical).lineLimit(2...5)
            Picker("Kind of meetup", selection: $model.category) {
                ForEach(MeetupCategory.allCases) { option in
                    Label(option.label, systemImage: option.icon).tag(option)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Topics").font(.caption).foregroundStyle(Color.dealioTextSecondary)
                HStack {
                    TextField("e.g. First-time buyers", text: $topicDraft)
                    Button("Add") { model.addTopic(topicDraft); topicDraft = "" }
                        .disabled(topicDraft.trimmedOrNil == nil)
                }
                if !model.topics.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(model.topics, id: \.self) { topic in
                            Button { model.topics.removeAll { $0 == topic } } label: {
                                HStack(spacing: 4) {
                                    Text(topic)
                                    Image(systemName: "xmark").font(.system(size: 8))
                                }
                                .font(.caption)
                                .foregroundStyle(Color.brandTeal)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Color.brandTeal.opacity(0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var whenSection: some View {
        Section("When") {
            DatePicker("Date", selection: $model.date, displayedComponents: [.date])
            DatePicker("Start time", selection: $model.time, displayedComponents: [.hourAndMinute])
        }
    }

    private var whereSection: some View {
        Section("Where") {
            Picker("How", selection: $model.mode) {
                ForEach(MeetupMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            if model.mode != .online {
                TextField("Address or landmark", text: $model.location, axis: .vertical).lineLimit(1...3)
                TextField("Google Maps link (optional)", text: $model.mapsLink)
                    .textInputAutocapitalization(.never)
            }
            if model.mode != .inPerson {
                TextField("Zoom or Meet link", text: $model.onlineLink)
                    .textInputAutocapitalization(.never)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Photos of the place").font(.caption).foregroundStyle(Color.dealioTextSecondary)
                    Spacer()
                    PhotosPicker(selection: $photoPick, matching: .images) {
                        Label("Add", systemImage: "plus").font(.caption.weight(.semibold))
                    }
                }
                if !model.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.photos, id: \.self) { photo in
                                ZStack(alignment: .topTrailing) {
                                    AsyncImage(url: AppConfig.resolveAssetURL(photo)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(Color.dealioFieldFill)
                                    }
                                    .frame(width: 92, height: 70)
                                    .clipShape(RoundedCornerShape12())
                                    Button { model.photos.removeAll { $0 == photo } } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var visibilitySection: some View {
        Section("Who can see this") {
            Toggle(isOn: $model.isPublic) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.isPublic ? "Open to your city" : "Invite only")
                    Text(model.isPublic
                         ? "Buyers in this city can find it and RSVP themselves."
                         : "Only the people you invite will see it.")
                        .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                }
            }
            if model.isPublic {
                TextField("City — e.g. Hyderabad", text: $model.city)
            }
            TextField("Limit numbers (leave blank for no limit)", text: $model.capacity)
                .keyboardType(.numberPad)
        }
    }

    private var inviteSection: some View {
        Section(model.picked.isEmpty && model.manual.isEmpty
                ? "Invite people"
                : "Inviting \(model.picked.count + model.manual.count)") {
            ForEach(candidates) { person in
                Button {
                    if model.picked.contains(person.id) { model.picked.remove(person.id) }
                    else { model.picked.insert(person.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: model.picked.contains(person.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(model.picked.contains(person.id) ? Color.brandTeal : Color.dealioTextSecondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(person.name).font(.subheadline)
                            Text(person.phone).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            HStack {
                TextField("Name", text: $manualName)
                TextField("Phone", text: $manualPhone).keyboardType(.phonePad)
                Button("Add") {
                    let digits = manualPhone.filter(\.isNumber)
                    guard let name = manualName.trimmedOrNil, digits.count >= 6 else { return }
                    model.manual.append(CpMeetupInviteePayload(contactId: nil, name: name,
                                                               phone: digits, email: nil))
                    manualName = ""; manualPhone = ""
                }
                .disabled(manualName.trimmedOrNil == nil || manualPhone.filter(\.isNumber).count < 6)
            }
            ForEach(model.manual) { person in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brandTeal)
                    Text(person.name)
                    Spacer()
                    Button("Remove") { model.manual.removeAll { $0.id == person.id } }
                        .font(.caption).foregroundStyle(Color.dealioError)
                }
            }
        }
    }

    private var notesSection: some View {
        Section {
            TextField("Anything you need to remember", text: $model.notes, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("Private note")
        } footer: {
            Text("Only you see this — it is not part of the invite.")
        }
    }

    private var candidates: [CpMeetupInviteePayload] {
        let fromContacts = model.people.contacts.map {
            CpMeetupInviteePayload(contactId: $0.id, name: $0.name, phone: $0.phone, email: $0.email)
        }
        let fromCustomers = model.people.customers.map {
            CpMeetupInviteePayload(contactId: nil, name: $0.name, phone: $0.phone, email: $0.email)
        }
        var seen = Set<String>()
        var result: [CpMeetupInviteePayload] = []
        for person in fromContacts + fromCustomers where !person.id.isEmpty {
            guard !seen.contains(person.id) else { continue }
            seen.insert(person.id)
            result.append(person)
        }
        return result
    }
}
