import SwiftUI

/// The other parties on a deal, and the thread you have with each.
///
/// A deal carries four threads — one private pair per couple, plus a three-way
/// group — and the backend has always supported them. The apps did not: each
/// screen had a single composer wired to whichever counterparty the backend
/// defaulted to, so a CP could talk to the builder and to nobody else.
///
/// Selecting a party here switches both the transcript and where the composer
/// sends. Which parties appear is decided by `rosterFor`; the backend is still
/// the authority and only returns threads the caller may read.

/// A selectable thread: the counterparty, or the three-way group.
struct ThreadTarget: Identifiable, Hashable {
    /// What the send endpoints call this: `builder` | `cp` | `customer` | `group`.
    let recipientRole: String
    let label: String
    let initials: String
    let color: Color
    var isGroup = false

    var id: String { recipientRole }
}

/// The threads `viewer` can choose between on this deal.
///
/// Mirrors the backend's `visibleThreadKeys`: the group only exists once a CP is
/// attached, and pre-booking the private builder↔customer pair is withheld so
/// the CP cannot be cut out — that conversation goes to the group instead.
func rosterFor(
    viewer: DealRole,
    hasCp: Bool,
    rawStatus: String?,
    builderName: String? = nil,
    cpName: String? = nil,
    customerName: String? = nil
) -> [ThreadTarget] {
    let escrowed = hasCp && stageIndex(rawStatus) < stageIndex("Booked")

    func target(_ role: String, _ name: String?, _ fallback: String, _ color: Color) -> ThreadTarget {
        let resolved = (name?.isEmpty == false) ? name! : fallback
        return ThreadTarget(recipientRole: role, label: resolved,
                            initials: initialsOf(resolved), color: color)
    }

    let builder = target("builder", builderName, "Builder", DealRole.builder.color)
    let cp = target("cp", cpName, "Advisor", DealRole.cp.color)
    let customer = target("customer", customerName, "Customer", DealRole.customer.color)
    let group = ThreadTarget(recipientRole: "group", label: "All three",
                             initials: "3", color: .dealioNavy, isGroup: true)

    var out: [ThreadTarget] = []
    switch viewer {
    case .cp:
        out = [builder, customer]
    case .builder:
        if hasCp { out.append(cp) }
        if !escrowed { out.append(customer) }
    case .customer:
        if hasCp { out.append(cp) }
        if !escrowed { out.append(builder) }
    }
    if hasCp { out.append(group) }
    return out
}

/// The `threadKey` a target maps to, for filtering the transcript.
func threadKeyFor(viewer: DealRole, target: ThreadTarget) -> String {
    guard !target.isGroup else { return "group" }
    let mine = viewer.rawValue.lowercased()
    return [mine, target.recipientRole].sorted().joined(separator: "-")
}

/// First letters of the first two words, upper-cased. `?` when there is nothing.
func initialsOf(_ name: String) -> String {
    let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
    let result = String(letters).uppercased()
    return result.isEmpty ? "?" : result
}

// MARK: - Party rail

struct PartyRail: View {
    let targets: [ThreadTarget]
    let selected: ThreadTarget?
    let onSelect: (ThreadTarget) -> Void
    var unreadOf: (ThreadTarget) -> Int = { _ in 0 }

    var body: some View {
        if !targets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ON THIS DEAL")
                    .font(.system(size: 9.5, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(Color.dealioTextSecondary)
                HStack(spacing: 8) {
                    ForEach(targets) { target in
                        tile(target, isSelected: target.recipientRole == selected?.recipientRole)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tile(_ target: ThreadTarget, isSelected: Bool) -> some View {
        Button { onSelect(target) } label: {
            VStack(spacing: 5) {
                Text(target.initials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(target.isGroup ? target.color : .white)
                    .frame(width: 26, height: 26)
                    .background(target.isGroup ? target.color.opacity(0.12) : target.color, in: Circle())
                Text(target.label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.dealioTextPrimary : Color.dealioTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                let unread = unreadOf(target)
                if unread > 0 {
                    Text("\(unread) new")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(target.color)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9).padding(.horizontal, 6)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(isSelected ? target.color : Color.dealioCardBorder,
                              lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}
