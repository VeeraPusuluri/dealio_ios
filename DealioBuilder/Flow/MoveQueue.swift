import SwiftUI

/// The deals that cannot progress without you.
///
/// Every home screen opened with metric tiles — true but inert, because a count
/// of leads never says which one needs you today. This is the same baton the
/// deal screens render, gathered into a to-do list and sorted so the ones going
/// stale surface first.

/// One row, already reduced to what the queue needs.
struct MoveItem: Identifiable, Hashable {
    let dealId: Int
    let title: String
    let subtitle: String
    let rawStatus: String
    var cpAgreed = false
    var customerConfirmed = false
    /// Days since the deal last moved; `nil` when unknown.
    var idleDays: Int? = nil

    var id: Int { dealId }
}

/// Keeps only the deals whose baton is on `viewer`, stalled first, then oldest.
///
/// Sorting stalled-first is what makes the queue double as the pipeline-hygiene
/// tool the platform lacked: the deal nobody has touched for a fortnight is the
/// one most likely to be lost, and it was previously indistinguishable from a
/// lead created this morning.
func movesFor(_ viewer: DealRole, _ items: [MoveItem]) -> [MoveItem] {
    items
        .filter { batonOf($0.rawStatus, cpAgreed: $0.cpAgreed, customerConfirmed: $0.customerConfirmed).heldBy(viewer) }
        .sorted { ($0.idleDays ?? 0) > ($1.idleDays ?? 0) }
}

struct MoveQueue: View {
    let viewer: DealRole
    let items: [MoveItem]
    let onOpen: (Int) -> Void
    var max: Int = 4
    /// Buyers get reassurance when the queue is empty; the trades get nothing.
    var emptyMessage: String? = nil

    private var moves: [MoveItem] { movesFor(viewer, items) }

    var body: some View {
        if !moves.isEmpty || emptyMessage != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("YOUR MOVE")
                        .font(.system(size: 9.5, weight: .black))
                        .tracking(0.7)
                        .foregroundStyle(Color.dealioTextSecondary)
                    if moves.count > max {
                        Text("\(moves.count)")
                            .font(.system(size: 9.5, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.dealioTeal, in: Capsule())
                    }
                }

                if moves.isEmpty, let emptyMessage {
                    Text(emptyMessage)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.dealioTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        ForEach(moves.prefix(max)) { item in
                            row(item)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ item: MoveItem) -> some View {
        let baton = batonOf(item.rawStatus, cpAgreed: item.cpAgreed, customerConfirmed: item.customerConfirmed)
        let stalled = (item.idleDays ?? 0) >= STALLED_AFTER_DAYS
        return Button { onOpen(item.dealId) } label: {
            HStack(spacing: 11) {
                Capsule()
                    .fill(stalled ? Color.dealioStatusAmber : Color.dealioTeal)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .lineLimit(1)
                    Text(baton.action)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.dealioTextSecondary)
                        .lineLimit(1)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.dealioTextSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 3) {
                    if let days = item.idleDays {
                        Text(days <= 0 ? "today" : "\(days)d")
                            .font(.system(size: 11, weight: stalled ? .bold : .medium))
                            .foregroundStyle(stalled ? Color.dealioStatusAmber : Color.dealioTextSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 11).padding(.trailing, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(stalled ? Color.dealioStatusAmber.opacity(0.4) : Color.dealioCardBorder,
                              lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
