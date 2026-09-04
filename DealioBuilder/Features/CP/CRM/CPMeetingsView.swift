import SwiftUI

/// Site visits the partner has arranged, as a list or a month calendar.
///
/// The partner's job on a completed visit is to capture what happened, so a row
/// opens a notes sheet with the rating the builder later reads. Mirrors
/// Android's `ui/cp/meetings/CpMeetingsScreen.kt`.

@MainActor
final class CPMeetingsModel: ObservableObject {
    @Published var meetings: [CpMeeting] = []
    @Published var loading = true
    @Published var error: String?
    @Published var message: String?

    private var cpUserId = 0

    func load(cpUserId: Int, silent: Bool = false) async {
        self.cpUserId = cpUserId
        if !silent { loading = meetings.isEmpty; error = nil }
        do { meetings = try await CPService.meetings(cpUserId: cpUserId) }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func saveNotes(meetingId: Int, notes: String, rating: Int?) async {
        do {
            try await CPService.saveMeetingNotes(cpUserId: cpUserId, meetingId: meetingId,
                                                 .init(notes: notes, cpRating: rating))
            message = "Visit notes saved"
            await load(cpUserId: cpUserId, silent: true)
        } catch { message = authMessage(error) }
    }
}

struct CPMeetingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CPMeetingsModel()
    @State private var mode: MeetingViewMode = .list
    @State private var noting: CpMeeting?

    private var calendarMeetings: [CalMeeting] {
        model.meetings.compactMap { meeting in
            CalMeeting(id: "\(meeting.id)",
                       dateString: meeting.confirmedDate ?? meeting.preferredDate,
                       time: meeting.confirmedTime ?? meeting.preferredTime,
                       title: meeting.customerName ?? "Visitor",
                       subtitle: meeting.projectName,
                       status: meeting.status,
                       color: statusColor(meeting.status))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(MeetingViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

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
                    MeetingCalendarView(meetings: calendarMeetings)
                } else if model.meetings.isEmpty {
                    ContentUnavailableView("No visits yet", systemImage: "calendar",
                        description: Text("Site visits you arrange for your leads appear here."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.meetings) { meeting in
                                Button { noting = meeting } label: { row(meeting) }
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
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Site visits")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(item: $noting) { meeting in
            VisitNotesSheet(meeting: meeting) { notes, rating in
                noting = nil
                Task { await model.saveNotes(meetingId: meeting.id, notes: notes, rating: rating) }
            }
            .presentationDetents([.medium])
        }
        .alert("Site visits", isPresented: Binding(get: { model.message != nil },
                                                   set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func reload() async { await model.load(cpUserId: auth.user?.id ?? 0) }

    private func row(_ meeting: CpMeeting) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(meeting.customerName?.nilIfEmpty ?? "Visitor")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Spacer()
                StatusBadge(text: meeting.status ?? "Pending", color: statusColor(meeting.status))
            }
            if let project = meeting.projectName?.nilIfEmpty {
                Text(project).font(.caption).foregroundStyle(Color.dealioTextSecondary)
            }
            if !meeting.whenText.isEmpty {
                Label(meeting.whenText, systemImage: "clock")
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            }
            if let notes = meeting.notes?.trimmedOrNil {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let phone = meeting.customerPhone?.trimmedOrNil {
                HStack(spacing: 8) {
                    Button { if let url = Share.telURL(phone) { openURL(url) } } label: {
                        Label("Call", systemImage: "phone.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.brandTeal)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(Capsule().strokeBorder(Color.brandTeal.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Text("Tap the card to log what happened")
                        .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

private struct VisitNotesSheet: View {
    let meeting: CpMeeting
    let onSave: (String, Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    @State private var rating = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meeting.customerName?.nilIfEmpty ?? "Visitor").font(.headline)
                        if !meeting.whenText.isEmpty {
                            Text(meeting.whenText).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                        }
                    }
                }
                Section("How did it go?") {
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { star in
                            Button { rating = (rating == star) ? 0 : star } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(star <= rating ? Color.orange : Color.dealioTextSecondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                }
                Section("Notes for the builder") {
                    TextField("What the buyer said, what they need next…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Visit notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(notes.trimmingCharacters(in: .whitespaces), rating > 0 ? rating : nil) }
                        .disabled(notes.trimmedOrNil == nil && rating == 0)
                }
            }
            .onAppear {
                notes = meeting.notes ?? ""
                rating = meeting.cpRating ?? 0
            }
        }
    }
}
