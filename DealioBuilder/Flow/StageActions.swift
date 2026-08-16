import SwiftUI

/// What each role may do at each stage.
///
/// The iOS twin of `STAGE_ACTIONS` in `Dealio_frontend/src/lib/dealStages.ts`
/// and the Android app's `ui/flow/StageActions.kt`. The stage × role gating and
/// the copy are shared verbatim; only the CTA targets are per-platform, because
/// each app navigates differently.
///
/// Holding this in one table is what stops a screen re-deriving its own gate and
/// offering, say, "Schedule site visit" on a visit that is already booked.
///
/// Add or change an action HERE and every screen picks it up.

/// Where a stage CTA leads.
///
/// A target names the *intent*; each screen decides how to serve it — presenting
/// a sheet, calling its model, or pushing a destination. A screen handles the
/// targets its role can receive and ignores the rest.
enum StageTarget {
    // Served in place, on the deal already open.
    /// CP: open the site-visit booking sheet.
    case requestVisit
    /// CP: open the follow-up dialog.
    case logFollowUp
    /// CP: agree to the deal terms.
    case agree

    // Elsewhere in the app.
    case builderMeetings
    case builderShortlists
    case builderCommissions
    case cpCommissions
    case customerVisits
    /// The buyer shortlists a unit on the deal's project page.
    case customerProject
    case customerLoan
}

/// The one action a role is offered at a stage.
struct StageCta {
    let label: String
    let target: StageTarget
}

/// - `headline`: what is happening at this stage, in this role's register.
/// - `cta`: the single next action, or `nil` when this role has nothing to do —
///   which is itself the answer, and the reason this table exists.
struct StageAction {
    let headline: String
    let cta: StageCta?
}

private func act(_ headline: String, _ label: String, _ target: StageTarget) -> StageAction {
    StageAction(headline: headline, cta: StageCta(label: label, target: target))
}

private func wait(_ headline: String) -> StageAction {
    StageAction(headline: headline, cta: nil)
}

/// Built statement-by-statement rather than as one nested literal: Swift
/// type-checks a large nested dictionary literal exponentially, and this table
/// is big enough to stall the compiler on it.
private let STAGE_ACTIONS: [String: [DealRole: StageAction]] = {
    var table: [String: [DealRole: StageAction]] = [:]

    table["New Lead"] = [
        .customer: wait("We have your enquiry — your advisor is setting up your search."),
        // The web sends the CP to a requirement form. The apps have no such
        // screen and no endpoint behind one, so the move actually available
        // here is the one that advances the lead.
        .cp: act("Capture what this buyer is looking for so the builder can match them.",
                 "Request a site visit", .requestVisit),
        .builder: wait("A channel partner has introduced a buyer. Nothing to do until they qualify them."),
    ]
    table["Profile Created"] = [
        .customer: wait("We have your requirement — your advisor is arranging a visit."),
        .cp: act("Requirement captured. Request a site visit with the builder.",
                 "Request a site visit", .requestVisit),
        .builder: wait("The buyer's requirement is in. Expect a visit request shortly."),
    ]
    // The two stages a visit is already on the books. Nobody may book another
    // one: the CP asked for it, the builder owes the slot, and offering
    // "schedule" to either would create a second meeting row for a visit that
    // already exists.
    table["Meeting Requested"] = [
        .customer: wait("The builder is confirming your site-visit slot."),
        .cp: wait("Visit requested — waiting on the builder to confirm a slot."),
        .builder: act("A site visit has been requested. Confirm a slot to keep the deal moving.",
                      "Confirm a site visit slot", .builderMeetings),
    ]
    table["Meeting Confirmed"] = [
        .customer: act("Your site visit is booked — see you there.",
                       "View your visit", .customerVisits),
        .cp: wait("Visit confirmed. Make sure the buyer attends."),
        .builder: act("Visit confirmed — the buyer is expected on site.",
                      "View meetings", .builderMeetings),
    ]
    table["Meeting Done"] = [
        .customer: act("Your site visit is done — shortlist the unit you liked and request a price.",
                       "Shortlist a unit", .customerProject),
        // The web routes to the follow-ups list; the deal screen already carries
        // the follow-up dialog, so the CP logs it without leaving.
        .cp: act("Visit complete. Follow up with the customer to move the deal forward.",
                 "Log a follow-up", .logFollowUp),
        .builder: act("Customer has visited. Review their shortlist when it arrives.",
                      "Review shortlists", .builderShortlists),
    ]
    // From here the web's CTAs deep-link back to the very page the viewer is on,
    // where the quote, the countersign and the booking already live. On mobile
    // those controls are on this screen too, so the card states the position and
    // leaves them to it rather than duplicating a button.
    table["Negotiation"] = [
        .customer: wait("Pricing & terms are being worked out. Review the quote and message your builder or CP."),
        .cp: act("Negotiate on the customer's behalf and agree to the deal terms.",
                 "Open deal & agree", .agree),
        .builder: wait("Share a pricing quote and negotiate terms with the customer."),
    ]
    table["Agreement"] = [
        .customer: wait("The agreement is ready. Confirm acceptance and upload your signed copy."),
        .cp: wait("Agreement shared — awaiting the customer's signature."),
        .builder: wait("Once the customer uploads the signed agreement, countersign to proceed."),
    ]
    table["Pending Booking"] = [
        .customer: wait("Your signed agreement was accepted — the booking is being confirmed."),
        .cp: wait("Agreement accepted — booking in progress with the builder."),
        .builder: wait("Confirm the booking to lock the unit for this customer."),
    ]
    table["Booked"] = [
        .customer: act("Unit booked! Apply for a home loan if you need financing.",
                       "Apply for a home loan", .customerLoan),
        .cp: act("Unit booked — your commission is being processed.",
                 "View commission", .cpCommissions),
        .builder: wait("Unit booked. Set up the payment schedule for the customer."),
    ]
    table["Closed"] = [
        // The web offers an interior vendor here. The apps have no vendor
        // surface — VENDOR was descoped platform-wide — so the buyer reads the
        // close and is sent nowhere rather than to a screen that does not exist.
        .customer: wait("Deal complete — welcome home!"),
        .cp: act("Deal closed. Track your commission payout.",
                 "Commission status", .cpCommissions),
        .builder: act("Deal closed. Release the channel-partner commission.",
                      "Release commission", .builderCommissions),
    ]

    return table
}()

/// The action `role` is offered at `rawStatus`.
///
/// Folds legacy spellings onto the canonical ten first, so a deal still carrying
/// "Site Visit Scheduled" reads as Meeting Confirmed and gets that stage's
/// answer — the very row most likely to be sitting on an old status.
func stageActionFor(_ rawStatus: String?, role: DealRole) -> StageAction {
    let stage = canonicalStage(rawStatus) ?? "New Lead"
    // Both lookups are total over the table above; the fallback only exists so a
    // future stage added to DEAL_STAGES without a row here degrades to silence
    // rather than trapping.
    guard let action = STAGE_ACTIONS[stage]?[role] else {
        return wait(buyerHeadline(rawStatus))
    }
    return action
}

// MARK: - Stage action card

/// The stage's headline and, when there is one, its single action.
///
/// Sits under `DealSpine` on all three deal screens — the spine says who the
/// deal is waiting on, this says what to do about it. When the role has nothing
/// to do the card is the headline alone; that absence is the fix, not an
/// omission.
///
/// `onAction` is invoked with the CTA's target. `nil` hides the button and
/// leaves the headline.
struct StageActionCard: View {
    let rawStatus: String?
    let viewer: DealRole
    var enabled = true
    var onAction: ((StageTarget) -> Void)? = nil

    var body: some View {
        let action = stageActionFor(rawStatus, role: viewer)
        VStack(alignment: .leading, spacing: 12) {
            Text(action.headline)
                .font(.system(size: 13))
                .foregroundStyle(Color.dealioTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let cta = action.cta, let onAction {
                Button { onAction(cta.target) } label: {
                    Text(cta.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(enabled ? Color.dealioTeal : Color.dealioButtonDisabled,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.dealioCardBorder, lineWidth: 1))
    }
}
