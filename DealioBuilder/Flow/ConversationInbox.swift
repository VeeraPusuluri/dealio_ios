import SwiftUI

/// Every conversation this user has, grouped by deal and then by party.
///
/// The deal screens gained a `PartyRail` — four threads per deal, one per pair
/// plus the group — but the three Conversations screens kept the model that
/// predates it: one row per deal, opening whichever thread the detail screen
/// happened to default to. So the inbox could not answer the only question an
/// inbox exists to answer — who is waiting on a reply — and a message from the
/// builder was indistinguishable from one from the buyer.
///
/// This renders the same roster the deal screen does, one row per thread, each
/// carrying its own last message and unread count. Tapping a row opens the deal
/// *on that thread*, which is why the deal-detail destinations take a thread.
///
/// The roster, the thread keys and the ordering are plain functions over data
/// the three portals already fetch, so this needs no new endpoint.

/// One deal in the inbox, reduced to what its party rows need.
struct InboxDeal: Identifiable {
    let dealId: Int
    /// Who or what this deal is about, in the viewer's terms.
    let title: String
    var subtitle: String = ""
    var rawStatus: String = ""
    var hasCp: Bool = false
    var builderName: String? = nil
    var cpName: String? = nil
    var customerName: String? = nil

    var id: Int { dealId }
}

/// A single thread row: the party, its key, and whatever the backend knows of it.
private struct InboxThread: Identifiable {
    let dealId: Int
    let target: ThreadTarget
    let threadKey: String
    let summary: ThreadSummary?

    var id: String { "\(dealId):\(threadKey)" }
    var unread: Int { summary?.unread ?? 0 }
    var lastAt: String { summary?.lastMessage?.createdAt ?? "" }
}

/// Last message + unread count for every thread on screen, in one request.
///
/// `POST /threads/summary` takes the (dealId, threadKey) pairs the caller
/// already knows and authorizes each one itself, so this is role-agnostic — the
/// same model serves the CP, builder and customer inboxes.
@MainActor
final class ThreadInboxModel: ObservableObject {
    @Published private(set) var summaries: [ThreadRef: ThreadSummary] = [:]

    func load(_ refs: [ThreadRef]) async {
        guard !refs.isEmpty else { return }
        summaries = await ThreadService.summaries(refs)
    }

    func summary(dealId: Int, threadKey: String) -> ThreadSummary? {
        summaries[ThreadRef(dealId: dealId, threadKey: threadKey)]
    }
}

struct ConversationInbox<Empty: View>: View {
    let viewer: DealRole
    let deals: [InboxDeal]
    /// Opens a deal on one of its threads. The role is what the rail calls the party.
    let onOpen: (_ dealId: Int, _ recipientRole: String) -> Void
    @ViewBuilder var empty: () -> Empty

    @StateObject private var model = ThreadInboxModel()

    // The roster is derived, not fetched: which threads exist follows from the
    // deal's stage and whether a CP is attached, exactly as on the deal screen.
    private var rows: [(deal: InboxDeal, threads: [InboxThread])] {
        deals.map { deal in
            let targets = rosterFor(
                viewer: viewer,
                hasCp: deal.hasCp,
                rawStatus: deal.rawStatus,
                builderName: deal.builderName,
                cpName: deal.cpName,
                customerName: deal.customerName
            )
            let threads = targets.map { target -> InboxThread in
                let key = threadKeyFor(viewer: viewer, target: target)
                return InboxThread(dealId: deal.dealId, target: target, threadKey: key,
                                   summary: model.summary(dealId: deal.dealId, threadKey: key))
            }
            // Unread first, then most recently spoken in — an inbox's job.
            let ordered = threads.sorted {
                if ($0.unread > 0) != ($1.unread > 0) { return $0.unread > 0 }
                return $0.lastAt > $1.lastAt
            }
            return (deal, ordered)
        }
    }

    private var refs: [ThreadRef] {
        rows.flatMap { row in row.threads.map { ThreadRef(dealId: $0.dealId, threadKey: $0.threadKey) } }
    }

    var body: some View {
        Group {
            if deals.isEmpty {
                empty()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(rows, id: \.deal.id) { row in
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.deal.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.dealioTextPrimary)
                                    if !row.deal.subtitle.isEmpty {
                                        Text(row.deal.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dealioTextSecondary)
                                    }
                                }
                                VStack(spacing: 0) {
                                    ForEach(row.threads) { thread in
                                        threadRow(thread) { onOpen(thread.dealId, thread.target.recipientRole) }
                                        if thread.id != row.threads.last?.id {
                                            Divider().padding(.leading, 48)
                                        }
                                    }
                                }
                                .background(Color(.secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task(id: refs) { await model.load(refs) }
    }

    private func threadRow(_ thread: InboxThread, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 11) {
                Text(thread.target.initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(thread.target.isGroup ? thread.target.color : .white)
                    .frame(width: 34, height: 34)
                    .background(thread.target.isGroup ? thread.target.color.opacity(0.12) : thread.target.color,
                                in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.target.label)
                        .font(.system(size: 13.5, weight: thread.unread > 0 ? .bold : .semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .lineLimit(1)
                    Text(thread.summary?.lastMessage?.message ?? "No messages yet")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.dealioTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    if let ago = shortAgo(thread.lastAt) {
                        Text(ago)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.dealioTextSecondary)
                    }
                    if thread.unread > 0 {
                        Text("\(thread.unread)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(thread.target.color, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// "now" / "4h" / "3d" — the shortest honest thing to put at the end of a row.
func shortAgo(_ iso: String?) -> String? {
    guard let iso, !iso.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let then = formatter.date(from: iso)
        ?? ISO8601DateFormatter().date(from: iso)
        ?? daysSince(iso).map { Date().addingTimeInterval(TimeInterval(-$0 * 86_400)) }
    guard let then else { return nil }

    let seconds = Date().timeIntervalSince(then)
    if seconds < 60 { return "now" }
    if seconds < 3_600 { return "\(Int(seconds / 60))m" }
    if seconds < 86_400 { return "\(Int(seconds / 3_600))h" }
    return "\(Int(seconds / 86_400))d"
}
