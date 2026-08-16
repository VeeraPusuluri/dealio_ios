import SwiftUI

/// The header block every deal screen opens with, for all three roles.
///
/// Only three things vary by role: whether the exact stage is shown under the
/// track, which register the labels are written in, and what the baton's action
/// button does. The shape is identical everywhere, which is what makes the three
/// portals read as one product.

extension DealRole {
    /// Role colour identifies people, never actions — CTAs keep the app accent.
    var color: Color {
        switch self {
        case .builder: return .dealioNavy
        case .cp: return .dealioTeal
        case .customer: return .dealioOrange
        }
    }

    /// Parses a wire role (`"builder"`, `"CP"`, `"customer"`), or `nil`.
    init?(wire: String?) {
        guard let wire else { return nil }
        switch wire.trimmingCharacters(in: .whitespaces).uppercased() {
        case "BUILDER": self = .builder
        case "CP", "CHANNEL_PARTNER": self = .cp
        case "CUSTOMER": self = .customer
        default: return nil
        }
    }
}

// The two states a waiting deal can be in, as colours.
extension Color {
    static let dealioStatusGreen = Color(hex: 0x059669)
    static let dealioStatusGreenBg = Color(hex: 0xE8F6F1)
    static let dealioStatusAmber = Color(hex: 0xD97706)
    static let dealioStatusAmberBg = Color(hex: 0xFDF3E7)
}

// MARK: - Phase track

/// Five-phase progress track: filled behind the current phase, hollow ahead.
///
/// `exactStage` is shown beneath the track for builder and CP, who work the
/// pipeline in its own vocabulary. Pass `nil` for a buyer — they must never see it.
struct PhaseTrack: View {
    let current: JourneyPhase
    var accent: Color = .dealioTeal
    var exactStage: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(JourneyPhase.allCases.enumerated()), id: \.element) { index, phase in
                    let done = index < current.rawValue
                    let active = index == current.rawValue
                    VStack(spacing: 5) {
                        ZStack {
                            // Connectors run behind the node, clipped to this
                            // cell's half-widths so the end nodes don't sprout stubs.
                            HStack(spacing: 18) {
                                connector(filled: done || active, visible: index > 0)
                                connector(filled: done, visible: index < JourneyPhase.allCases.count - 1)
                            }
                            node(done: done, active: active)
                        }
                        .frame(height: 18)
                        Text(phase.label)
                            .font(.system(size: 9, weight: active ? .bold : .medium))
                            .foregroundStyle(done || active ? accent : Color.dealioTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let exactStage {
                Text("Stage · \(exactStage)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dealioTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func connector(filled: Bool, visible: Bool) -> some View {
        Capsule()
            .fill(!visible ? .clear : (filled ? accent.opacity(0.45) : Color.dealioCardBorder))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func node(done: Bool, active: Bool) -> some View {
        if done {
            Circle().fill(accent).frame(width: 18, height: 18)
                .overlay(Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
        } else if active {
            Circle().fill(accent.opacity(0.18)).frame(width: 18, height: 18)
                .overlay(Circle().fill(accent).frame(width: 9, height: 9))
        } else {
            Circle().fill(Color.dealioCardBorder).frame(width: 11, height: 11)
        }
    }
}

// MARK: - Baton card

/// The answer to "is this waiting on me?".
///
/// Owns the screen's single primary action, so no deal screen ever presents two
/// competing main CTAs. When the viewer does not hold the baton it shows who
/// does and offers a nudge instead.
struct BatonCard: View {
    let baton: Baton
    let viewer: DealRole
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil
    var onNudge: (() -> Void)? = nil
    /// How long the current holder has had it, for stalled styling.
    var waitingDays: Int? = nil
    var buyerRegister = false

    private var yours: Bool { baton.heldBy(viewer) }
    private var stalled: Bool { !yours && (waitingDays ?? 0) >= STALLED_AFTER_DAYS }

    private var accent: Color {
        if baton.isComplete { return .dealioStatusGreen }
        if yours { return .dealioTeal }
        if stalled { return .dealioStatusAmber }
        return .dealioCardBorder
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                chip
                // The buyer never reads the imperative written for the CP or
                // builder — they read the same wait, phrased for them.
                Text(buyerRegister ? baton.buyerCopy : baton.action)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !yours, let waitingDays, !baton.isComplete {
                    Text(waitingDays <= 0 ? "Since today" : "Since \(waitingDays) days ago")
                        .font(.system(size: 10.5, weight: stalled ? .bold : .regular))
                        .foregroundStyle(stalled ? Color.dealioStatusAmber : Color.dealioTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if yours, let onAction, !baton.isComplete {
                Button(action: onAction) {
                    Text(actionLabel ?? "Do it")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.dealioNavy, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if !yours, let onNudge, !baton.isComplete {
                Button(action: onNudge) {
                    Text("Nudge")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color.dealioTeal)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.dealioTeal.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(accent, lineWidth: yours || stalled ? 2 : 1))
    }

    private var chip: some View {
        let spec: (text: String, fg: Color, bg: Color) = {
            if baton.isComplete { return ("COMPLETE", .dealioStatusGreen, .dealioStatusGreenBg) }
            if yours { return ("YOUR MOVE", .white, .dealioTeal) }
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

// MARK: - Deal spine

/// `PhaseTrack` + `BatonCard`, the block that opens every deal screen.
///
/// `buyerRegister` is true for the customer portal — it hides the exact stage
/// and switches every string to the buyer's language.
struct DealSpine: View {
    let rawStatus: String?
    let viewer: DealRole
    var cpAgreed = false
    var customerConfirmed = false
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil
    var onNudge: (() -> Void)? = nil
    var waitingDays: Int? = nil
    var buyerRegister = false

    var body: some View {
        VStack(spacing: 14) {
            PhaseTrack(
                current: phaseOf(rawStatus),
                accent: buyerRegister ? .dealioOrange : .dealioTeal,
                // The buyer must never see pipeline vocabulary; the others work in it.
                exactStage: buyerRegister ? nil : canonicalStage(rawStatus)
            )
            BatonCard(
                baton: batonOf(rawStatus, cpAgreed: cpAgreed, customerConfirmed: customerConfirmed),
                viewer: viewer,
                actionLabel: actionLabel,
                onAction: onAction,
                onNudge: onNudge,
                waitingDays: waitingDays,
                buyerRegister: buyerRegister
            )
        }
        .frame(maxWidth: .infinity)
    }
}
