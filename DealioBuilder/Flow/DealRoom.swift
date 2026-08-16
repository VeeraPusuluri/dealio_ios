import SwiftUI

/// One deal, as any of the three parties sees it.
///
/// The builder and CP screens were near-identical copies of each other — a
/// transcript and a composer, each wired to whichever counterparty the backend
/// happened to default to — and the customer had no deal screen at all. Rather
/// than port three of them, this is the one screen all three roles open, with
/// the role deciding only what it is allowed to see and do.
///
/// Top to bottom: where the deal is and who owes the next move (`DealSpine`),
/// what to do about it (`StageActionCard`), who else is on it (`PartyRail`),
/// the selected thread's transcript, and what has happened so far
/// (`ActivityLedger`).

/// A deal id, wrapped so it can drive `navigationDestination(item:)`.
struct DealRoute: Identifiable, Hashable {
    let id: Int
}

/// A deal reduced to what the room renders, so each role's own DTO can feed it.
struct DealRoomData {
    let id: Int
    var status: String?
    var title: String
    var subtitle: String = ""
    var builderName: String?
    var cpName: String?
    var customerName: String?
    var cpAgreed = false
    var customerConfirmed = false
    var idleDays: Int?
    var messages: [DealMessage] = []
    var events: [DealEvent] = []

    var hasCp: Bool { !(cpName ?? "").isEmpty }
}

struct DealRoom: View {
    let viewer: DealRole
    let deal: DealRoomData
    /// Sends `message` to one party — the rail's `recipientRole`.
    let onSend: (_ message: String, _ recipientRole: String) async -> Void
    /// Serves a stage CTA. Targets the screen doesn't handle should be ignored.
    var onStageAction: ((StageTarget) -> Void)? = nil

    @State private var selected: ThreadTarget?
    @State private var draft = ""
    @State private var sending = false
    @State private var nudgeMessage: String?
    @State private var summaries: [ThreadRef: ThreadSummary] = [:]

    private var roster: [ThreadTarget] {
        rosterFor(viewer: viewer, hasCp: deal.hasCp, rawStatus: deal.status,
                  builderName: deal.builderName, cpName: deal.cpName,
                  customerName: deal.customerName)
    }

    private var activeTarget: ThreadTarget? { selected ?? roster.first }

    private var activeKey: String? {
        activeTarget.map { threadKeyFor(viewer: viewer, target: $0) }
    }

    /// The backend only sends threads this caller is party to, but a deal opened
    /// from a stale list can still carry messages for a thread the rail no
    /// longer offers — so filter rather than trust.
    private var transcript: [DealMessage] {
        guard let activeKey else { return deal.messages }
        return deal.messages.filter { $0.thread == activeKey }
    }

    private var buyerRegister: Bool { viewer == .customer }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DealSpine(
                        rawStatus: deal.status,
                        viewer: viewer,
                        cpAgreed: deal.cpAgreed,
                        customerConfirmed: deal.customerConfirmed,
                        actionLabel: stageActionFor(deal.status, role: viewer).cta?.label,
                        onAction: onStageAction.map { handler in
                            { if let cta = stageActionFor(deal.status, role: viewer).cta { handler(cta.target) } }
                        },
                        onNudge: { Task { await nudge() } },
                        waitingDays: deal.idleDays,
                        buyerRegister: buyerRegister
                    )

                    StageActionCard(rawStatus: deal.status, viewer: viewer, onAction: onStageAction)

                    if roster.count > 1 {
                        PartyRail(
                            targets: roster,
                            selected: activeTarget,
                            onSelect: select,
                            unreadOf: { unread(for: $0) }
                        )
                    }

                    transcriptSection
                    ActivityLedger(events: deal.events)
                }
                .padding(16)
            }
            if activeTarget != nil { composer }
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .task(id: deal.id) { await refreshSummaries() }
        .task(id: activeKey) { await markActiveRead() }
        .alert("Nudge sent", isPresented: .constant(nudgeMessage != nil)) {
            Button("OK") { nudgeMessage = nil }
        } message: {
            Text(nudgeMessage ?? "")
        }
    }

    // MARK: Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let activeTarget {
                Text(activeTarget.isGroup ? "ALL THREE" : "WITH \(activeTarget.label.uppercased())")
                    .font(.system(size: 9.5, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(Color.dealioTextSecondary)
            }
            if transcript.isEmpty {
                Text(emptyTranscriptCopy)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.dealioTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                ForEach(transcript) { bubble($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyTranscriptCopy: String {
        guard let activeTarget else { return "No messages yet." }
        if activeTarget.isGroup { return "Nothing in the group thread yet." }
        return "No messages with \(activeTarget.label) yet."
    }

    private func bubble(_ message: DealMessage) -> some View {
        let mine = DealRole(wire: message.senderRole) == viewer
        let author = DealRole(wire: message.senderRole)
        return HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                Text(mine ? "You" : (message.senderName ?? author?.label.capitalized ?? "Them"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(mine ? Color.dealioTextSecondary : (author?.color ?? .dealioTextSecondary))
                Text(message.message).font(.subheadline)
                if let ago = shortAgo(message.createdAt) {
                    Text(ago).font(.system(size: 9)).foregroundStyle(Color.dealioTextSecondary)
                }
            }
            .padding(10)
            .background(mine ? Color.dealioTeal.opacity(0.15) : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !mine { Spacer(minLength: 40) }
        }
    }

    // MARK: Composer

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(composerPrompt, text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? Color.dealioTeal : Color.dealioButtonDisabled)
            }
            .disabled(!canSend)
        }
        .padding(12)
        .background(.bar)
    }

    private var composerPrompt: String {
        guard let activeTarget else { return "Type a message…" }
        return activeTarget.isGroup ? "Message all three…" : "Message \(activeTarget.label)…"
    }

    private var canSend: Bool {
        !sending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Actions

    private func select(_ target: ThreadTarget) {
        selected = target
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let target = activeTarget else { return }
        draft = ""
        sending = true
        await onSend(text, target.recipientRole)
        sending = false
        await refreshSummaries()
    }

    private func nudge() async {
        do {
            let result = try await ThreadService.nudge(dealId: deal.id)
            nudgeMessage = result.action.map { "We've asked them to \($0.lowercased())." }
                ?? "We've let them know this is waiting on them."
        } catch {
            nudgeMessage = authMessage(error)
        }
    }

    private func unread(for target: ThreadTarget) -> Int {
        let key = threadKeyFor(viewer: viewer, target: target)
        return summaries[ThreadRef(dealId: deal.id, threadKey: key)]?.unread ?? 0
    }

    private func refreshSummaries() async {
        let refs = roster.map {
            ThreadRef(dealId: deal.id, threadKey: threadKeyFor(viewer: viewer, target: $0))
        }
        summaries = await ThreadService.summaries(refs)
    }

    /// Opening a thread reads it. Best-effort — a failure costs a stale badge.
    private func markActiveRead() async {
        guard let activeKey else { return }
        await ThreadService.markRead(dealId: deal.id, threadKey: activeKey)
        summaries[ThreadRef(dealId: deal.id, threadKey: activeKey)]?.unreadCount = 0
    }
}
