import SwiftUI

/// What has happened on this deal, newest first.
///
/// Every row is dotted in the colour of whoever acted, so a glance answers "is
/// this deal moving, and who is moving it?" — the question the ledger exists
/// for. Summaries are phrased server-side at insert time; nothing is re-derived
/// here.
struct ActivityLedger: View {
    let events: [DealEvent]
    var max: Int = 6

    private var shown: [DealEvent] { Array(events.prefix(max)) }

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("ACTIVITY")
                    .font(.system(size: 9.5, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(Color.dealioTextSecondary)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, event in
                        row(event, isLast: index == shown.count - 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ event: DealEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor(event.actorRole))
                    .frame(width: 7, height: 7)
                // A connector to the next entry, so the column reads as one thread.
                if !isLast {
                    Rectangle()
                        .fill(Color.dealioCardBorder)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.summary ?? "")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let when = relativeDay(event.createdAt) {
                    Text(when)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dealioTextSecondary)
                }
            }
            .padding(.bottom, isLast ? 0 : 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func dotColor(_ actorRole: String?) -> Color {
        DealRole(wire: actorRole)?.color ?? .dealioCardBorder
    }
}

/// "today" / "3d ago" from an ISO timestamp, or `nil` when there is no usable date.
///
/// The Android original documented this and then returned the raw `yyyy-MM-dd`
/// string, so the ledger read "2026-08-04" under every entry. Day granularity is
/// all the subtitle needs, which `daysSince` already gives us.
func relativeDay(_ iso: String?) -> String? {
    guard let days = daysSince(iso) else { return nil }
    switch days {
    case 0: return "today"
    case 1: return "yesterday"
    default: return "\(days)d ago"
    }
}
