import SwiftUI

/// The deals that cannot progress without you.
///
/// Every home screen opened with metric tiles — true but inert, because a count
/// of leads never says which one needs you today. This is the same baton the
/// deal screens render, gathered into a to-do list and sorted so the ones going
/// stale surface first. Mirrors Android's `ui/flow/MoveQueue.kt`.

/// One row, already reduced to what the queue needs.
struct MoveItem: Identifiable {
    let dealId: Int
    let title: String
    let subtitle: String
    let rawStatus: String
    var cpAgreed = false
    var customerConfirmed = false
    /// Days since the deal last moved; nil when unknown.
    var idleDays: Int?

    var id: Int { dealId }
}

/// Keep only the deals whose baton is on `viewer`, stalled first, then oldest.
///
/// Sorting stalled-first is what makes the queue double as the pipeline-hygiene
/// tool the platform lacked: the deal nobody has touched for a fortnight is the
/// one most likely to be lost, and it was previously indistinguishable from a
/// lead created this morning.
func movesFor(_ viewer: DealRole, _ items: [MoveItem]) -> [MoveItem] {
    items
        .filter {
            DealFlow.baton($0.rawStatus, cpAgreed: $0.cpAgreed,
                           customerConfirmed: $0.customerConfirmed).heldBy(viewer)
        }
        .sorted { ($0.idleDays ?? 0) > ($1.idleDays ?? 0) }
}

struct MoveQueue: View {
    let viewer: DealRole
    let items: [MoveItem]
    let onOpen: (Int) -> Void
    var max: Int = 4
    var accent: Color = .brandTeal
    /// Buyers get reassurance when the queue is empty; the trades get nothing.
    var emptyMessage: String?

    var body: some View {
        let moves = movesFor(viewer, items)
        if !moves.isEmpty || emptyMessage != nil {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(moves.isEmpty ? "Nothing needs you" : "Your move")
                        .font(.headline)
                        .foregroundStyle(Color.dealioTextPrimary)
                    if !moves.isEmpty {
                        Text("\(moves.count)")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
                Text(moves.isEmpty ? (emptyMessage ?? "") : "Deals that cannot progress without you")
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .padding(.top, 3)
                    .padding(.bottom, 12)

                ForEach(moves.prefix(max)) { item in
                    Button { onOpen(item.dealId) } label: { row(item) }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ item: MoveItem) -> some View {
        let baton = DealFlow.baton(item.rawStatus, cpAgreed: item.cpAgreed,
                                   customerConfirmed: item.customerConfirmed)
        let stalled = (item.idleDays ?? 0) >= DealFlow.stalledAfterDays
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(viewer.color.opacity(0.15))
                Text(item.title.trimmingCharacters(in: .whitespaces).prefix(1).uppercased().nilIfEmpty ?? "?")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(viewer.color)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)
                // The action, not the stage — the queue is a to-do list.
                Text(baton.action)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(stalled ? Color.dealioStatusAmber : accent)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dealioTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let days = item.idleDays {
                Text(days <= 0 ? "today" : "\(days)d")
                    .font(.caption.weight(stalled ? .bold : .medium))
                    .foregroundStyle(stalled ? Color.dealioStatusAmber : Color.dealioTextSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(stalled ? Color.dealioStatusAmber : Color.dealioCardBorder,
                              lineWidth: stalled ? 1.6 : 1)
        )
    }
}

/// Whole days between an ISO-8601 timestamp and now, or nil if unparseable.
///
/// Only the date part is used — the queue sorts by staleness in days, and a deal
/// touched this morning versus last night is the same answer.
func idleDaysSince(_ iso: String?) -> Int? {
    guard let date = ISO8601.parse(iso) else { return nil }
    let calendar = Calendar.current
    return calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                   to: calendar.startOfDay(for: Date())).day
}
