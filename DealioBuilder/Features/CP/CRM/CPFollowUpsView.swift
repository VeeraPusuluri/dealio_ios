import SwiftUI

/// Follow-ups the partner owes their leads.
///
/// A follow-up hangs off a deal, so creating one starts by picking the lead it
/// is about. Mirrors Android's `ui/cp/followups/FollowUpsScreen.kt`.

@MainActor
final class CPFollowUpsModel: ObservableObject {
    @Published var items: [CpFollowUp] = []
    @Published var leads: [CpLead] = []
    @Published var loading = true
    @Published var error: String?
    @Published var message: String?

    private var cpUserId = 0

    /// Overdue first, then today, then the rest — the order a partner works in.
    var ordered: [CpFollowUp] {
        items.filter { !$0.done }.sorted { $0.dueDate < $1.dueDate } + items.filter(\.done)
    }

    func load(cpUserId: Int, silent: Bool = false) async {
        self.cpUserId = cpUserId
        if !silent { loading = items.isEmpty; error = nil }
        do {
            async let followUps = CPService.followUps(cpUserId: cpUserId)
            async let leads = CPService.leads(cpUserId: cpUserId)
            items = try await followUps
            self.leads = (try? await leads) ?? []
        } catch { self.error = authMessage(error) }
        loading = false
    }

    func create(dealId: Int, dueDate: String, dueTime: String?, reason: String) async {
        do {
            try await CPService.createFollowUp(cpUserId: cpUserId, .init(
                dealId: dealId, dueDate: dueDate, dueTime: dueTime, reason: reason
            ))
            message = "Follow-up scheduled"
            await load(cpUserId: cpUserId, silent: true)
        } catch { message = authMessage(error) }
    }

    func markDone(_ followUp: CpFollowUp) async {
        do {
            try await CPService.markFollowUpDone(cpUserId: cpUserId, id: followUp.id)
            // Flip locally first so the row settles before the reload lands.
            if let index = items.firstIndex(where: { $0.id == followUp.id }) { items[index].done = true }
            await load(cpUserId: cpUserId, silent: true)
        } catch { message = authMessage(error) }
    }
}

struct CPFollowUpsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPFollowUpsModel()
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
                ContentUnavailableView("No follow-ups due", systemImage: "bell.badge",
                    description: Text("Schedule one against a lead and it appears here on its day."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.ordered) { item in
                            row(item)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await reload() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Follow-ups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { composing = true } label: { Label("Schedule", systemImage: "plus") }
                    .disabled(model.leads.isEmpty)
            }
        }
        .task { await reload() }
        .sheet(isPresented: $composing) {
            FollowUpComposer(leads: model.leads) { dealId, date, time, reason in
                composing = false
                Task { await model.create(dealId: dealId, dueDate: date, dueTime: time, reason: reason) }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Follow-ups", isPresented: Binding(get: { model.message != nil },
                                                  set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func reload() async { await model.load(cpUserId: auth.user?.id ?? 0) }

    private func row(_ item: CpFollowUp) -> some View {
        let overdue = !item.done && isOverdue(item.dueDate)
        return HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: item.done ? "checkmark" : "bell.fill",
                      tint: item.done ? .green : (overdue ? .red : .orange), size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.customerName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text(item.projectName).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                if !item.reason.isEmpty {
                    Text(item.reason)
                        .font(.caption)
                        .foregroundStyle(Color.dealioTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text([item.dueDate, item.dueTime].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption2.weight(overdue ? .bold : .regular))
                    .foregroundStyle(overdue ? Color.dealioStatusAmber : Color.dealioTextSecondary)
            }
            Spacer(minLength: 8)
            if !item.done {
                Button { Task { await model.markDone(item) } } label: {
                    Text("Done")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.brandTeal)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Color.brandTeal.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .opacity(item.done ? 0.6 : 1)
    }

    /// Dates arrive as `yyyy-MM-dd`, so a plain string comparison against today
    /// is enough — and cheaper than parsing every row on every redraw.
    private func isOverdue(_ dueDate: String) -> Bool {
        guard dueDate.count >= 10 else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return String(dueDate.prefix(10)) < formatter.string(from: Date())
    }
}

// MARK: - Composer

private struct FollowUpComposer: View {
    let leads: [CpLead]
    let onCreate: (Int, String, String?, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dealId: Int?
    @State private var due = Date()
    @State private var includeTime = true
    @State private var reason = ""

    private static let reasons = ["Call back", "Share brochure", "Site visit reminder",
                                  "Price discussion", "Documents pending"]

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
                Section("When") {
                    DatePicker("Due", selection: $due,
                               displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date])
                    Toggle("Set a time", isOn: $includeTime)
                }
                Section("Why") {
                    TextField("Reason", text: $reason, axis: .vertical).lineLimit(1...3)
                    // The five reasons that cover most of what a partner logs;
                    // anything else is typed above.
                    WrapPills(options: Self.reasons, selection: reason, accent: .brandTeal) { reason = $0 }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle("Schedule follow-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        guard let dealId, let text = reason.trimmedOrNil else { return }
                        onCreate(dealId, Self.dateString(due), includeTime ? Self.timeString(due) : nil, text)
                    }
                    .disabled(dealId == nil || reason.trimmedOrNil == nil)
                }
            }
        }
    }

    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
