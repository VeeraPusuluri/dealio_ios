import SwiftUI

// MARK: - Deal detail

@MainActor
final class CPDealDetailModel: ObservableObject {
    @Published var deal: CpDealDetail?
    @Published var loading = true
    @Published var error: String?

    func load(cpUserId: Int, dealId: Int) async {
        loading = deal == nil
        error = nil
        do { deal = try await APIClient.shared.get("/cp/\(cpUserId)/deals/\(dealId)") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    /// `recipientRole` picks the thread: `builder` | `customer` | `group`.
    func send(cpUserId: Int, dealId: Int, text: String, to recipientRole: String) async {
        do {
            try await APIClient.shared.call(
                "/cp/\(cpUserId)/deals/\(dealId)/messages",
                body: MessageRequest(message: text, recipientRole: recipientRole)
            )
        } catch {
            self.error = authMessage(error)
        }
        await load(cpUserId: cpUserId, dealId: dealId)
    }

    /// Schedules a follow-up against this deal — the CP's move at Meeting Done.
    func logFollowUp(cpUserId: Int, dealId: Int, due: Date, reason: String) async {
        do {
            try await APIClient.shared.call(
                "/cp/\(cpUserId)/follow-ups",
                body: CreateFollowUpRequest(
                    dealId: dealId,
                    dueDate: MeetingAnswerSheet.dateFormatter.string(from: due),
                    dueTime: MeetingAnswerSheet.timeFormatter.string(from: due),
                    reason: reason
                )
            )
        } catch {
            self.error = authMessage(error)
        }
        await load(cpUserId: cpUserId, dealId: dealId)
    }

    /// The CP half of the two-sided agreement at the Agreement stage.
    func agree(cpUserId: Int, dealId: Int) async {
        do {
            try await APIClient.shared.call("/cp/\(cpUserId)/deals/\(dealId)/agree", method: "PATCH")
        } catch {
            self.error = authMessage(error)
        }
        await load(cpUserId: cpUserId, dealId: dealId)
    }
}

struct CPDealDetailView: View {
    let dealId: Int
    let title: String

    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPDealDetailModel()
    @State private var route: StageTarget?
    @State private var loggingFollowUp = false

    private var cpUserId: Int { auth.user?.id ?? 0 }

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let deal = model.deal {
                DealRoom(
                    viewer: .cp,
                    deal: roomData(deal),
                    onSend: { text, recipient in
                        await model.send(cpUserId: cpUserId, dealId: dealId, text: text, to: recipient)
                    },
                    onStageAction: handle
                )
            } else {
                VStack {
                    ErrorBanner(message: model.error ?? "Couldn't load this deal.").padding()
                    Spacer()
                }
            }
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $route) { target in
            switch target {
            case .cpCommissions: CPEarningsView()
            default: EmptyView()
            }
        }
        .sheet(isPresented: $loggingFollowUp) {
            FollowUpFormView(customerName: model.deal?.customerName ?? title) { due, reason in
                Task { await model.logFollowUp(cpUserId: cpUserId, dealId: dealId, due: due, reason: reason) }
            }
        }
        .task { await model.load(cpUserId: cpUserId, dealId: dealId) }
    }

    /// Agreeing and logging a follow-up happen here rather than elsewhere, so
    /// neither leaves the deal. Targets this screen doesn't serve fall through
    /// to navigation.
    private func handle(_ target: StageTarget) {
        switch target {
        case .agree:
            Task { await model.agree(cpUserId: cpUserId, dealId: dealId) }
        case .logFollowUp:
            loggingFollowUp = true
        default:
            route = target
        }
    }

    private func roomData(_ deal: CpDealDetail) -> DealRoomData {
        DealRoomData(
            id: deal.id,
            status: deal.status,
            title: deal.customerName ?? title,
            subtitle: deal.projectName ?? "",
            builderName: deal.builderName,
            // The CP is one of the parties, so the rail always has a CP side.
            cpName: auth.user?.fullName ?? "You",
            customerName: deal.customerName,
            cpAgreed: deal.cpAgreed ?? false,
            customerConfirmed: deal.customerConfirmed ?? false,
            idleDays: daysSince(deal.updatedAt ?? deal.createdAt),
            messages: deal.messages ?? [],
            events: deal.events ?? []
        )
    }
}
