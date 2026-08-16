import SwiftUI

@MainActor
final class BuilderDealDetailModel: ObservableObject {
    @Published var deal: DealDetail?
    @Published var loading = true
    @Published var error: String?

    func load(builderId: Int, dealId: Int) async {
        loading = deal == nil
        error = nil
        do { deal = try await APIClient.shared.get("/builder/\(builderId)/deals/\(dealId)") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    /// `recipientRole` picks the thread: `cp` | `customer` | `group`.
    func send(builderId: Int, dealId: Int, text: String, to recipientRole: String) async {
        do {
            try await APIClient.shared.call(
                "/builder/\(builderId)/deals/\(dealId)/messages",
                body: MessageRequest(message: text, recipientRole: recipientRole)
            )
        } catch {
            self.error = authMessage(error)
        }
        await load(builderId: builderId, dealId: dealId)
    }
}

struct BuilderDealDetailView: View {
    let dealId: Int
    let title: String

    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealDetailModel()
    @State private var route: StageTarget?

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let deal = model.deal {
                DealRoom(
                    viewer: .builder,
                    deal: roomData(deal),
                    onSend: { text, recipient in
                        if let id = await auth.resolvedBuilderId() {
                            await model.send(builderId: id, dealId: dealId, text: text, to: recipient)
                        }
                    },
                    onStageAction: { route = $0 }
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
            case .builderMeetings: BuilderMeetingsView()
            case .builderShortlists: BuilderShortlistsView()
            case .builderCommissions: BuilderCommissionsView()
            default: EmptyView()
            }
        }
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id, dealId: dealId) } }
    }

    private func roomData(_ deal: DealDetail) -> DealRoomData {
        DealRoomData(
            id: deal.id,
            status: deal.status,
            title: deal.customerName ?? title,
            subtitle: deal.projectName ?? "",
            builderName: deal.builderName,
            cpName: deal.cpName,
            customerName: deal.customerName,
            cpAgreed: deal.cpAgreed ?? false,
            customerConfirmed: deal.customerConfirmed ?? false,
            idleDays: deal.idleDays,
            messages: deal.messages ?? [],
            events: deal.events ?? []
        )
    }
}

/// Lets a `StageTarget` drive a `navigationDestination(item:)`.
extension StageTarget: Identifiable {
    public var id: String { String(describing: self) }
}
