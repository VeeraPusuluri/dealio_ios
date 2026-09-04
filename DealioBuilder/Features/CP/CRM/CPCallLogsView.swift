import SwiftUI

/// Calls the partner has logged against their leads.
///
/// Logging a call can also schedule the next one, which is how a partner keeps a
/// pipeline warm without a separate trip to the follow-ups screen. Mirrors
/// Android's `ui/cp/calllogs/CallLogsScreen.kt`.

@MainActor
final class CPCallLogsModel: ObservableObject {
    @Published var items: [CpCallLog] = []
    @Published var leads: [CpLead] = []
    @Published var loading = true
    @Published var error: String?
    @Published var message: String?

    private var cpUserId = 0

    func load(cpUserId: Int, silent: Bool = false) async {
        self.cpUserId = cpUserId
        if !silent { loading = items.isEmpty; error = nil }
        do {
            async let logs = CPService.callLogs(cpUserId: cpUserId)
            async let leads = CPService.leads(cpUserId: cpUserId)
            items = try await logs
            self.leads = (try? await leads) ?? []
        } catch { self.error = authMessage(error) }
        loading = false
    }

    func log(_ request: CPService.CreateCallLogRequest) async {
        do {
            try await CPService.createCallLog(cpUserId: cpUserId, request)
            message = "Call logged"
            await load(cpUserId: cpUserId, silent: true)
        } catch { message = authMessage(error) }
    }
}

struct CPCallLogsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPCallLogsModel()
    @State private var composing = false

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.items.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else if model.items.isEmpty {
                ContentUnavailableView("No calls logged", systemImage: "phone.badge.checkmark",
                    description: Text("Log a call against a lead to keep a record of what was said."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.items) { log in row(log) }
                    }
                    .padding(16)
                }
                .refreshable { await reload() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Call logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { composing = true } label: { Label("Log a call", systemImage: "plus") }
                    .disabled(model.leads.isEmpty)
            }
        }
        .task { await reload() }
        .sheet(isPresented: $composing) {
            CallLogComposer(leads: model.leads) { request in
                composing = false
                Task { await model.log(request) }
            }
            .presentationDetents([.large])
        }
        .alert("Call logs", isPresented: Binding(get: { model.message != nil },
                                                 set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func reload() async { await model.load(cpUserId: auth.user?.id ?? 0) }

    private func row(_ log: CpCallLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: icon(log.outcome), tint: tint(log.outcome), size: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.customerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Spacer()
                    StatusBadge(text: log.outcome.nilIfEmpty ?? "Logged", color: tint(log.outcome))
                }
                Text(log.projectName).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                if let notes = log.notes?.trimmedOrNil {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(Color.dealioTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    if !log.duration.isEmpty {
                        Label(log.duration, systemImage: "clock").font(.caption2)
                    }
                    if let next = log.nextFollowUp?.trimmedOrNil {
                        Label("Next: \(next)", systemImage: "bell").font(.caption2)
                    }
                }
                .foregroundStyle(Color.dealioTextSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func icon(_ outcome: String) -> String {
        switch outcome.lowercased() {
        case let o where o.contains("no answer") || o.contains("missed"): return "phone.down.fill"
        case let o where o.contains("interest"): return "hand.thumbsup.fill"
        case let o where o.contains("not"): return "hand.thumbsdown.fill"
        default: return "phone.fill"
        }
    }

    private func tint(_ outcome: String) -> Color {
        switch outcome.lowercased() {
        case let o where o.contains("no answer") || o.contains("missed"): return .orange
        case let o where o.contains("not interested"): return .red
        case let o where o.contains("interest"): return .green
        default: return .brandTeal
        }
    }
}

private struct CallLogComposer: View {
    let leads: [CpLead]
    let onLog: (CPService.CreateCallLogRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dealId: Int?
    @State private var outcome = outcomes[0]
    @State private var duration = "5 min"
    @State private var notes = ""
    @State private var scheduleNext = false
    @State private var next = Date().addingTimeInterval(60 * 60 * 24)

    private static let outcomes = ["Interested", "Call back later", "No answer",
                                   "Site visit booked", "Not interested"]
    private static let durations = ["1 min", "5 min", "10 min", "20 min", "30 min+"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Which lead") {
                    Picker("Lead", selection: $dealId) {
                        Text("Choose a lead").tag(Int?.none)
                        ForEach(leads) { lead in
                            Text("\(lead.customerName) · \(lead.projectName)").tag(Int?.some(lead.id))
                        }
                    }
                }
                Section("How it went") {
                    WrapPills(options: Self.outcomes, selection: outcome, accent: .brandTeal) { outcome = $0 }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    WrapPills(options: Self.durations, selection: duration, accent: .brandTeal) { duration = $0 }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                Section("Next call") {
                    Toggle("Schedule a follow-up", isOn: $scheduleNext)
                    if scheduleNext {
                        DatePicker("When", selection: $next, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Log a call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let dealId else { return }
                        onLog(.init(
                            dealId: dealId, outcome: outcome, duration: duration,
                            notes: notes.trimmedOrNil,
                            nextFollowUp: scheduleNext ? Self.dateString(next) : nil,
                            nextFollowUpTime: scheduleNext ? Self.timeString(next) : nil
                        ))
                    }
                    .disabled(dealId == nil)
                }
            }
        }
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
