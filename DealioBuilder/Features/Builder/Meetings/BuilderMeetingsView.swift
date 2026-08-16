import SwiftUI

@MainActor
final class BuilderMeetingsModel: ObservableObject {
    @Published var meetings: [BuilderMeeting] = []
    @Published var loading = true
    @Published var error: String?
    @Published var working = false
    @Published var toast: String?

    func load(builderId: Int) async {
        loading = meetings.isEmpty
        error = nil
        do {
            meetings = try await APIClient.shared.get("/builder/\(builderId)/meetings")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    /// Answers a visit request.
    ///
    /// Approving with no explicit slot falls back to the one the customer asked
    /// for — a visit "confirmed for null at null" is worse than no answer. The
    /// other statuses carry no slot at all, so nothing is written over the one
    /// already on the row.
    func answer(
        builderId: Int, meeting: BuilderMeeting, answer: MeetingAnswer,
        date: String?, time: String?, notes: String?
    ) async {
        working = true
        defer { working = false }
        let slotDate = date ?? (answer.status == "Confirmed" ? meeting.preferredDate : nil)
        let slotTime = time ?? (answer.status == "Confirmed" ? meeting.preferredTime : nil)
        do {
            try await APIClient.shared.call(
                "/builder/\(builderId)/meetings/\(meeting.id)",
                method: "PATCH",
                body: MeetingUpdateRequest(status: answer.status, notes: notes,
                                           confirmedDate: slotDate, confirmedTime: slotTime)
            )
            toast = answer.done
        } catch {
            toast = authMessage(error)
        }
        await load(builderId: builderId)
    }
}

struct BuilderMeetingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderMeetingsModel()
    @State private var mode: MeetingViewMode = .list
    @State private var answering: PendingAnswer?

    private var calMeetings: [CalMeeting] {
        model.meetings.compactMap { m in
            CalMeeting(id: "\(m.id)", dateString: m.confirmedDate ?? m.preferredDate,
                       time: m.confirmedTime ?? m.preferredTime, title: m.customerName ?? "Visitor",
                       subtitle: m.meetingType, status: m.status, color: statusColor(m.status))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(MeetingViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if mode == .calendar {
                    MeetingCalendarView(meetings: calMeetings)
                } else if model.meetings.isEmpty {
                    ContentUnavailableView("No site visits", systemImage: "calendar",
                        description: Text("Customer visit requests will appear here."))
                } else {
                    List(model.meetings) { meeting in
                        row(meeting)
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Site Visits")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .sheet(item: $answering) { pending in
            MeetingAnswerSheet(meeting: pending.meeting, answer: pending.answer) { date, time, notes in
                Task {
                    if let id = await auth.resolvedBuilderId() {
                        await model.answer(builderId: id, meeting: pending.meeting,
                                           answer: pending.answer, date: date, time: time, notes: notes)
                    }
                }
            }
        }
        .alert("Done", isPresented: .constant(model.toast != nil)) {
            Button("OK") { model.toast = nil }
        } message: {
            Text(model.toast ?? "")
        }
    }

    private func row(_ meeting: BuilderMeeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.customerName ?? "Visitor").font(.headline)
                Spacer()
                StatusBadge(text: meeting.status ?? "Pending", color: statusColor(meeting.status))
            }
            if let type = meeting.meetingType {
                Label(type, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
            }
            if !meeting.whenText.isEmpty {
                Label(meeting.whenText, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
            }
            if let phone = meeting.customerPhone, !phone.isEmpty {
                Label(phone, systemImage: "phone").font(.caption).foregroundStyle(.secondary)
            }

            let answers = MeetingAnswer.forStatus(meeting.status)
            if !answers.isEmpty {
                HStack(spacing: 8) {
                    ForEach(answers) { answer in
                        Button {
                            answering = PendingAnswer(meeting: meeting, answer: answer)
                        } label: {
                            Label(answer.cta, systemImage: answer.systemImage)
                                .font(.caption.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .foregroundStyle(answer.isPrimary ? .white : answer.tint)
                                .background(
                                    answer.isPrimary ? answer.tint : answer.tint.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .disabled(model.working)
                .opacity(model.working ? 0.5 : 1)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A visit and the answer being given to it, held together so the sheet has both.
private struct PendingAnswer: Identifiable {
    let meeting: BuilderMeeting
    let answer: MeetingAnswer
    var id: String { "\(meeting.id):\(answer.rawValue)" }
}
