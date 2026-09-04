import SwiftUI
import UniformTypeIdentifiers

/// One deal, as the buyer sees it.
///
/// The spine is in the buyer's register: no stage chip, no pipeline vocabulary.
/// This screen used to show the sales team's words ("Pending Booking") to the
/// person buying the home, with no sense of progress at all. Mirrors Android's
/// `ui/customer/journey/DealDetailScreen.kt`.

@MainActor
final class CustomerDealRoomModel: ObservableObject {
    @Published var deal: CustomerDeal?
    @Published var loading = true
    @Published var error: String?
    @Published var working = false
    @Published var message: String?

    // The unit picker
    @Published var picking = false
    @Published var loadingUnits = false
    @Published var units: [UnitRow] = []
    /// The project behind the matrix — carries the builderId a shortlist needs.
    @Published var project: Project?
    @Published var pickedUnit: UnitRow?
    @Published var shortlistedUnitId: String?

    private var dealId = 0
    private var phone = ""

    func load(dealId: Int, phone: String, silent: Bool = false) async {
        self.dealId = dealId
        self.phone = phone
        if !silent { loading = deal == nil; error = nil }
        do {
            let deals = try await CustomerService.myDeals(phone: phone)
            guard let found = deals.first(where: { $0.dealId == dealId }) else {
                error = "Deal not found"
                loading = false
                return
            }
            deal = found
        } catch { self.error = authMessage(error) }
        loading = false
    }

    /// Nudge whoever the deal is waiting on; the cooldown reply is worth showing.
    func nudge() async {
        working = true
        defer { working = false }
        do {
            _ = try await ThreadService.nudge(dealId: dealId)
            message = "Nudged. They'll see what's needed next."
        } catch { message = authMessage(error) }
    }

    func confirm() async {
        await act { try await CustomerService.confirmDeal(self.dealId, phone: self.phone) }
    }

    func acceptNegotiation() async {
        await act { try await CustomerService.acceptNegotiation(self.dealId, phone: self.phone) }
    }

    // MARK: The unit picker
    //
    // Naming an actual flat is the move the app was missing. The buyer could
    // shortlist a *configuration* from the project page — "2 BHK" — which told
    // the builder what shape of home they wanted and gave them nothing to
    // reserve. The website has always picked off the project's unit matrix, and
    // it is the unit id that the shortlist, the pricing request and eventually
    // the booking all travel on.

    /// Open the picker, loading the project's matrix behind it.
    ///
    /// The project is fetched rather than taken off the deal because the deal
    /// payload carries a project *name* and no inventory — and because the
    /// project row is also where the builderId a shortlist needs lives.
    func startPickingUnit() async {
        guard let projectId = deal?.projectId, projectId > 0 else { return }
        picking = true
        loadingUnits = true
        pickedUnit = nil
        do {
            let project = try await CustomerService.project(projectId)
            self.project = project
            // Sold and booked units stay in the list: a buyer needs to see the
            // whole board, including what has gone. The grid refuses to select them.
            units = Units.of(project)
        } catch {
            picking = false
            message = authMessage(error)
        }
        loadingUnits = false
    }

    func shortlistPickedUnit() async {
        guard let unit = pickedUnit, let deal else { return }
        guard let builderId = project?.builderId else {
            message = "This project has no builder attached yet."
            return
        }
        working = true
        defer { working = false }
        do {
            try await CustomerService.shortlistUnit(.init(
                customerPhone: phone, builderId: builderId, projectId: deal.projectId,
                cpId: nil, unitId: unit.id, unitDetails: CustomerService.unitDetails(unit)
            ))
            shortlistedUnitId = unit.id
            picking = false
            message = "Unit \(unit.id) shortlisted. The builder will review it and share a price."
            await load(dealId: dealId, phone: phone, silent: true)
        } catch { message = authMessage(error) }
    }

    /// Submits the signed agreement the buyer picked. An unreadable pick reports
    /// rather than uploading an empty file, which the server would accept as a
    /// valid agreement.
    func uploadSignedAgreement(from url: URL) async {
        working = true
        defer { working = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            message = "Could not read that file. Try another."
            return
        }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/pdf"
        do {
            _ = try await CustomerService.uploadSignedAgreement(
                dealId: dealId, phone: phone, data: data,
                fileName: url.lastPathComponent, mimeType: mime
            )
            message = "Signed agreement sent to the builder."
            await load(dealId: dealId, phone: phone, silent: true)
        } catch { message = authMessage(error) }
    }

    private func act(_ block: @escaping () async throws -> Void) async {
        working = true
        defer { working = false }
        do {
            try await block()
            message = "Done!"
            await load(dealId: dealId, phone: phone, silent: true)
        } catch { message = authMessage(error) }
    }
}

// A buyer can accept a quote while the deal still reads "Negotiation" — the
// status column has no separate "quote sent" state — so this action is offered
// even when the baton is not on them. It renders as a secondary control, so it
// never competes with a spine saying the deal is waiting on someone else.
func showAcceptFor(_ deal: CustomerDeal) -> Bool {
    deal.dealStatus.lowercased().contains("negotiation") && !deal.customerConfirmed
}

func showConfirmFor(_ deal: CustomerDeal) -> Bool {
    let status = deal.dealStatus.lowercased()
    return !deal.customerConfirmed && !showAcceptFor(deal)
        && (status.contains("agreement") || status.contains("pending booking") || status.contains("booked"))
}

struct CustomerDealRoomView: View {
    let dealId: Int
    var titleFallback: String = "Deal"

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CustomerDealRoomModel()
    @State private var showAgreementPicker = false
    @State private var goVisits = false
    @State private var goLoan = false
    @State private var goConversations = false

    /// True when the deal is genuinely waiting on the buyer and there is a
    /// confirm to make — the one case where the spine should carry the action.
    private var ownsConfirm: Bool {
        guard let deal = model.deal else { return false }
        return DealFlow.baton(deal.dealStatus, cpAgreed: deal.cpAgreed,
                              customerConfirmed: deal.customerConfirmed).heldBy(.customer)
            && showConfirmFor(deal)
    }

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.deal == nil {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else if let deal = model.deal {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        DealSpine(
                            rawStatus: deal.dealStatus,
                            viewer: .customer,
                            cpAgreed: deal.cpAgreed,
                            customerConfirmed: deal.customerConfirmed,
                            // When the deal really is waiting on the buyer, the
                            // spine carries the action instead of a second
                            // button below it.
                            actionLabel: ownsConfirm ? "Confirm" : nil,
                            onAction: ownsConfirm ? { Task { await model.confirm() } } : nil,
                            onNudge: { Task { await model.nudge() } },
                            buyerRegister: true
                        )

                        StageActionCard(rawStatus: deal.dealStatus, viewer: .customer,
                                        enabled: !model.working) { target in
                            handle(target)
                        }

                        if deal.customerConfirmed {
                            Label("Confirmed by you", systemImage: "checkmark.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dealioStatusGreen)
                        }

                        if !ownsConfirm { dealActions(deal) }

                        if deal.loanCaseId != nil { loanCard(deal) }
                        if !deal.dealDocuments.isEmpty { documentsSection(deal) }

                        // Messaging is one tap away rather than embedded: the
                        // advisor here is the same advisor on every other deal,
                        // with one shared conversation.
                        Button { goConversations = true } label: {
                            Label("Message", systemImage: "bubble.left")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.customerAccent, lineWidth: 1)
                                )
                                .foregroundStyle(Color.customerAccent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
                .refreshable { await reload() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle(model.deal?.projectName ?? titleFallback)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .navigationDestination(isPresented: $goVisits) { CustomerVisitsView() }
        .navigationDestination(isPresented: $goLoan) {
            CustomerLoanApplyView(projectId: model.deal?.projectId, builderId: model.project?.builderId)
        }
        .navigationDestination(isPresented: $goConversations) { CustomerConversationsView() }
        .sheet(isPresented: $model.picking) {
            UnitPickerSheet(
                projectName: model.deal?.projectName ?? "this project",
                units: model.units, loading: model.loadingUnits, working: model.working,
                picked: model.pickedUnit,
                onPick: { model.pickedUnit = $0 },
                onConfirm: { Task { await model.shortlistPickedUnit() } }
            )
            .presentationDetents([.large])
        }
        // Any document type: buyers send back a scan, a photo of the signed
        // pages, or the PDF they were sent.
        .fileImporter(isPresented: $showAgreementPicker,
                      allowedContentTypes: [.pdf, .image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await model.uploadSignedAgreement(from: url) }
            }
        }
        .alert("Your deal", isPresented: Binding(get: { model.message != nil },
                                                 set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func handle(_ target: StageTarget) {
        switch target {
        case .customerVisits: goVisits = true
        case .customerLoan: goLoan = true
        // Served in place rather than by navigating: the buyer is choosing a
        // flat *on this deal*, and the project page has no idea which deal
        // sent them.
        case .pickUnit: Task { await model.startPickingUnit() }
        case .uploadSignedAgreement: showAgreementPicker = true
        default: break
        }
    }

    private func reload() async {
        await model.load(dealId: dealId, phone: auth.phone)
    }

    @ViewBuilder
    private func dealActions(_ deal: CustomerDeal) -> some View {
        if showAcceptFor(deal) {
            secondaryButton("Accept negotiated price") { Task { await model.acceptNegotiation() } }
        } else if showConfirmFor(deal) {
            secondaryButton("Confirm deal") { Task { await model.confirm() } }
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.customerAccent, lineWidth: 1)
                )
                .foregroundStyle(Color.customerAccent)
        }
        .buttonStyle(.plain)
        .disabled(model.working)
    }

    private func loanCard(_ deal: CustomerDeal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Home loan")
            InfoLine("Amount", deal.loanAmount.map { Money.inr($0) })
            InfoLine("Status", deal.loanStatus)
            InfoLine("Tenure", deal.tenureMonths.map { "\($0 / 12) years" })
            InfoLine("Interest", deal.interestRate.map { "\($0)%" })
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(cornerRadius: 16)
    }

    private func documentsSection(_ deal: CustomerDeal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Documents")
            ForEach(deal.dealDocuments) { doc in
                Button {
                    if let url = doc.fileURL { openURL(url) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text").foregroundStyle(Color.customerAccent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(doc.name.nilIfEmpty ?? doc.docType)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.dealioTextPrimary)
                                .lineLimit(1)
                            Text(doc.docType).font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The buyer's unit picker — the whole board, with only what's free selectable.
///
/// Sold and booked units are shown rather than filtered out. A grid with the
/// taken flats missing looks like a smaller building, and a buyer who was told
/// on site that "the seventh floor has gone" needs to see that reflected here or
/// they will not trust the rest of it.
private struct UnitPickerSheet: View {
    let projectName: String
    let units: [UnitRow]
    let loading: Bool
    let working: Bool
    let picked: UnitRow?
    let onPick: (UnitRow) -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pick your unit").font(.headline)
                    Text(projectName).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                }

                // The grid scrolls inside a bounded box rather than the sheet
                // scrolling as a whole. A real tower is 50-odd floors, so with
                // one scroll region the buyer had to travel the entire building
                // *past* the unit they had just tapped to reach the button.
                if loading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    ScrollView {
                        UnitMatrixGrid(units: units, selectable: true,
                                       selected: picked?.id, onSelect: onPick)
                            .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 380)
                }

                if let picked { PickedUnitRow(unit: picked) }

                Button(action: onConfirm) {
                    Text(working ? "Shortlisting…" : (picked.map { "Shortlist unit \($0.id)" } ?? "Select a unit"))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(picked == nil || working ? Color.customerAccent.opacity(0.4) : Color.customerAccent,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(picked == nil || working)

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.customerSurface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
