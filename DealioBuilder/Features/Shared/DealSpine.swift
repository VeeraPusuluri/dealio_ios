import SwiftUI

/// The header block every deal screen opens with, for all three roles.
///
/// Only three things vary by role: whether the exact stage is shown under the
/// track, which register the labels are written in, and what the baton's action
/// button does. The shape is identical everywhere, which is what makes the three
/// portals read as one product. Mirrors Android's `ui/flow/DealSpine.kt`.

// MARK: - Status palette

extension Color {
    static let dealioStatusGreen = Color.adaptive(light: 0x059669, dark: 0x34D399)
    static let dealioStatusGreenBg = Color.adaptive(light: 0xE8F6F1, dark: 0x0F2A22)
    static let dealioStatusAmber = Color.adaptive(light: 0xD97706, dark: 0xFBBF24)
    static let dealioStatusAmberBg = Color.adaptive(light: 0xFDF3E7, dark: 0x2E220C)
}

// MARK: - PhaseTrack

/// Five-phase progress track: filled behind the current phase, hollow ahead.
///
/// `exactStage` is shown beneath the track for builder and CP, who work the
/// pipeline in its own vocabulary. Pass nil for a buyer — they must never see it.
struct PhaseTrack: View {
    let current: JourneyPhase
    var accent: Color = .brandTeal
    var exactStage: String?

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(JourneyPhase.allCases) { phase in
                    let index = phase.rawValue
                    let done = index < current.rawValue
                    let active = index == current.rawValue
                    VStack(spacing: 5) {
                        ZStack {
                            HStack(spacing: 0) {
                                connector(filled: done || active, visible: index > 0)
                                Spacer().frame(width: 18)
                                connector(filled: done, visible: index < JourneyPhase.allCases.count - 1)
                            }
                            node(done: done, active: active)
                        }
                        .frame(height: 18)

                        Text(phase.label)
                            .font(.system(size: 9, weight: active ? .bold : .medium))
                            .foregroundStyle(done || active ? accent : Color.dealioTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let exactStage {
                Text("Stage · \(exactStage)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dealioTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func connector(filled: Bool, visible: Bool) -> some View {
        Capsule()
            .fill(!visible ? Color.clear : (filled ? accent.opacity(0.45) : Color.dealioCardBorder))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func node(done: Bool, active: Bool) -> some View {
        if done {
            ZStack {
                Circle().fill(accent).frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
            }
        } else if active {
            ZStack {
                Circle().fill(accent.opacity(0.18)).frame(width: 18, height: 18)
                Circle().fill(accent).frame(width: 9, height: 9)
            }
        } else {
            Circle().fill(Color.dealioCardBorder).frame(width: 11, height: 11)
        }
    }
}

// MARK: - BatonCard

/// The answer to "is this waiting on me?".
///
/// Owns the screen's single primary action, so no deal screen ever presents two
/// competing main CTAs. When the viewer does not hold the baton it shows who does
/// and offers a nudge instead.
struct BatonCard: View {
    let baton: Baton
    let viewer: DealRole
    var actionLabel: String?
    var onAction: (() -> Void)?
    var onNudge: (() -> Void)?
    /// How long the current holder has had it, for stalled styling.
    var waitingDays: Int?
    var buyerRegister = false

    private var yours: Bool { baton.heldBy(viewer) }
    private var stalled: Bool { !yours && (waitingDays ?? 0) >= DealFlow.stalledAfterDays }

    private var accent: Color {
        if baton.isComplete { return .dealioStatusGreen }
        if yours { return .brandTeal }
        if stalled { return .dealioStatusAmber }
        return .dealioCardBorder
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                chip
                VStack(alignment: .leading, spacing: 3) {
                    // The buyer never reads the imperative written for the CP or
                    // builder — they read the same wait, phrased for them.
                    Text(buyerRegister ? baton.buyerCopy : baton.action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !yours, let waitingDays, !baton.isComplete {
                        Text(waitingDays <= 0 ? "Since today" : "Since \(waitingDays) days ago")
                            .font(.system(size: 10.5, weight: stalled ? .bold : .regular))
                            .foregroundStyle(stalled ? Color.dealioStatusAmber : Color.dealioTextSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if yours, let onAction, !baton.isComplete {
                Button(action: onAction) {
                    Text(actionLabel ?? "Do it")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Color.dealioNavy, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else if !yours, let onNudge, !baton.isComplete {
                Button(action: onNudge) {
                    Text("Nudge")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .overlay(Capsule().strokeBorder(Color.brandTeal.opacity(0.5), lineWidth: 1))
                        .foregroundStyle(Color.brandTeal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent, lineWidth: (yours || stalled) ? 2 : 1)
        )
    }

    private var chip: some View {
        let spec: (text: String, fg: Color, bg: Color) = {
            if baton.isComplete { return ("COMPLETE", .dealioStatusGreen, .dealioStatusGreenBg) }
            if yours { return ("YOUR MOVE", .white, .brandTeal) }
            if buyerRegister { return ("NOTHING NEEDED YET", .dealioOrange, Color.dealioOrange.opacity(0.12)) }
            let who = baton.holders.map(\.label).joined(separator: " and ").uppercased()
            return ("WAITING ON \(who)",
                    stalled ? .dealioStatusAmber : .dealioNavy,
                    stalled ? .dealioStatusAmberBg : Color.dealioNavy.opacity(0.07))
        }()
        return Text(spec.text)
            .font(.system(size: 9.5, weight: .black))
            .tracking(0.5)
            .foregroundStyle(spec.fg)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(spec.bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - DealSpine

/// `PhaseTrack` + `BatonCard`, the block that opens every deal screen.
///
/// `buyerRegister` is true for the customer portal — it hides the exact stage and
/// switches every string to the buyer's language.
struct DealSpine: View {
    let rawStatus: String?
    let viewer: DealRole
    var cpAgreed = false
    var customerConfirmed = false
    var actionLabel: String?
    var onAction: (() -> Void)?
    var onNudge: (() -> Void)?
    var waitingDays: Int?
    var buyerRegister = false

    var body: some View {
        let baton = DealFlow.baton(rawStatus, cpAgreed: cpAgreed, customerConfirmed: customerConfirmed)
        let accent: Color = buyerRegister ? .dealioOrange : .brandTeal
        VStack(spacing: 14) {
            PhaseTrack(
                current: DealFlow.phase(rawStatus),
                accent: accent,
                // The buyer must never see pipeline vocabulary; the others work in it.
                exactStage: buyerRegister ? nil : DealFlow.canonicalStage(rawStatus)
            )
            BatonCard(
                baton: baton, viewer: viewer, actionLabel: actionLabel,
                onAction: onAction, onNudge: onNudge,
                waitingDays: waitingDays, buyerRegister: buyerRegister
            )
        }
    }
}

// MARK: - ActivityLedger

/// What has happened on this deal, newest first. Every row is dotted in the
/// colour of whoever acted, so a glance answers "is this deal moving, and who is
/// moving it?". Summaries are phrased server-side; nothing is re-derived here.
struct ActivityLedger: View {
    let events: [DealEvent]
    var max: Int = 6

    var body: some View {
        let shown = Array(events.prefix(max))
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("ACTIVITY")
                    .font(.system(size: 9.5, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(Color.dealioTextSecondary)
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Circle().fill(dotColor(event.actorRole)).frame(width: 7, height: 7)
                            if index != shown.count - 1 {
                                Rectangle().fill(Color.dealioCardBorder).frame(width: 1, height: 20)
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.summary)
                                .font(.footnote)
                                .foregroundStyle(Color.dealioTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let created = event.createdAt, created.count >= 10 {
                                Text(String(created.prefix(10)))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.dealioTextSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, index == shown.count - 1 ? 0 : 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dotColor(_ actorRole: String?) -> Color {
        switch (actorRole ?? "").lowercased() {
        case "builder": return DealRole.builder.color
        case "cp": return DealRole.cp.color
        case "customer": return DealRole.customer.color
        default: return .dealioCardBorder
        }
    }
}

/// One entry on a deal's activity ledger — `…/deals/:id` → `events[]`.
struct DealEvent: Codable, Identifiable {
    let id: Int
    let actorRole: String?
    let summary: String
    let createdAt: String?
}
