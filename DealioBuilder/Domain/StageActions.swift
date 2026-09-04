import SwiftUI

/// What each role may do at each stage.
///
/// The iOS twin of Android's `ui/flow/StageActions.kt` and the web's
/// `STAGE_ACTIONS` in `Dealio_frontend/src/lib/dealStages.ts`. The stage × role
/// gating and the copy are shared verbatim; only the CTA targets are per-platform,
/// because each app navigates differently.
///
/// Add or change an action HERE and all three portals pick it up.

/// Where a stage CTA leads. A target names the *intent*; each screen decides how
/// to serve it — opening a sheet, calling the model, or navigating. A screen
/// handles the targets its role can receive and ignores the rest.
enum StageTarget {
    // Served in place, on the deal already open
    case requestVisit
    case logFollowUp
    case agree
    case uploadSignedAgreement
    case pickUnit

    // Elsewhere in the app
    case builderMeetings
    case builderShortlists
    case builderCommissions
    case builderAcceptAgreement
    case cpCommissions
    case customerVisits
    case customerProject
    case customerLoan
}

/// The one action a role is offered at a stage.
struct StageCta { let label: String; let target: StageTarget }

/// - `headline`: what is happening at this stage, in this role's register.
/// - `cta`: the single next action, or nil when this role has nothing to do —
///   which is itself the answer, and the reason this table exists.
struct StageAction { let headline: String; let cta: StageCta? }

private func act(_ headline: String, _ label: String, _ target: StageTarget) -> StageAction {
    StageAction(headline: headline, cta: StageCta(label: label, target: target))
}

private func wait(_ headline: String) -> StageAction { StageAction(headline: headline, cta: nil) }

private let stageActions: [String: [DealRole: StageAction]] = [
    "New Lead": [
        .customer: wait("We have your enquiry — your advisor is setting up your search."),
        .cp: act("Capture what this buyer is looking for so the builder can match them.",
                 "Request a site visit", .requestVisit),
        .builder: wait("A channel partner has introduced a buyer. Nothing to do until they qualify them."),
    ],
    "Profile Created": [
        .customer: wait("We have your requirement — your advisor is arranging a visit."),
        .cp: act("Requirement captured. Request a site visit with the builder.",
                 "Request a site visit", .requestVisit),
        .builder: wait("The buyer's requirement is in. Expect a visit request shortly."),
    ],
    // The two stages a visit is already on the books. Nobody may book another one:
    // the CP asked for it, the builder owes the slot.
    "Meeting Requested": [
        .customer: wait("The builder is confirming your site-visit slot."),
        .cp: wait("Visit requested — waiting on the builder to confirm a slot."),
        .builder: act("A site visit has been requested. Confirm a slot to keep the deal moving.",
                      "Confirm a site visit slot", .builderMeetings),
    ],
    "Meeting Confirmed": [
        .customer: act("Your site visit is booked — see you there.", "View your visit", .customerVisits),
        .cp: wait("Visit confirmed. Make sure the buyer attends."),
        .builder: act("Visit confirmed — the buyer is expected on site.", "View meetings", .builderMeetings),
    ],
    "Meeting Done": [
        // A buyer can only name the flat they want once they have stood in it, so
        // this is where the unit picker lives — the actual matrix, not a
        // configuration ("2 BHK") the builder cannot reserve.
        .customer: act("Your site visit is done — pick the unit you liked and we'll ask the builder for a price.",
                       "Pick your unit", .pickUnit),
        .cp: act("Visit complete. Follow up with the customer to move the deal forward.",
                 "Log a follow-up", .logFollowUp),
        .builder: act("Customer has visited. Review their shortlist when it arrives.",
                      "Review shortlists", .builderShortlists),
    ],
    "Negotiation": [
        .customer: wait("Pricing & terms are being worked out. Review the quote and message your builder or CP."),
        .cp: act("Negotiate on the customer's behalf and agree to the deal terms.",
                 "Open deal & agree", .agree),
        .builder: wait("Share a pricing quote and negotiate terms with the customer."),
    ],
    "Agreement": [
        // Without this the deal cannot leave Agreement at all: the builder's
        // accept-agreement returns 400 until a signed document exists on the row.
        .customer: act("The agreement is ready. Confirm acceptance and upload your signed copy.",
                       "Upload signed copy", .uploadSignedAgreement),
        .cp: wait("Agreement shared — awaiting the customer's signature."),
        .builder: act("Once the customer uploads the signed agreement, countersign to proceed.",
                      "Countersign agreement", .builderAcceptAgreement),
    ],
    "Pending Booking": [
        .customer: wait("Your signed agreement was accepted — the booking is being confirmed."),
        .cp: wait("Agreement accepted — booking in progress with the builder."),
        .builder: wait("Confirm the booking to lock the unit for this customer."),
    ],
    "Booked": [
        .customer: act("Unit booked! Apply for a home loan if you need financing.",
                       "Apply for a home loan", .customerLoan),
        .cp: act("Unit booked — your commission is being processed.", "View commission", .cpCommissions),
        .builder: wait("Unit booked. Set up the payment schedule for the customer."),
    ],
    "Closed": [
        .customer: wait("Deal complete — welcome home!"),
        .cp: act("Deal closed. Track your commission payout.", "Commission status", .cpCommissions),
        .builder: act("Deal closed. Release the channel-partner commission.",
                      "Release commission", .builderCommissions),
    ],
]

/// The action a `role` is offered at `rawStatus`. Folds legacy spellings onto the
/// canonical ten first, so a deal still carrying "Site Visit Scheduled" reads as
/// Meeting Confirmed and gets that stage's answer.
func stageActionFor(_ rawStatus: String?, role: DealRole) -> StageAction {
    let stage = DealFlow.canonicalStage(rawStatus) ?? "New Lead"
    return stageActions[stage]?[role]
        ?? stageActions["New Lead"]![role]!
}

// MARK: - StageActionCard

/// The stage's headline and, when there is one, its single action.
///
/// Sits under `DealSpine` on all three deal screens — the spine says who the deal
/// is waiting on, this says what to do about it. When the role has nothing to do
/// the card is the headline alone; that absence is the fix, not an omission.
struct StageActionCard: View {
    let rawStatus: String?
    let viewer: DealRole
    var enabled: Bool = true
    /// Invoked with the CTA's target. Nil, or a target the screen does not serve,
    /// hides the button and leaves the headline.
    var onAction: ((StageTarget) -> Void)?

    var body: some View {
        let action = stageActionFor(rawStatus, role: viewer)
        VStack(alignment: .leading, spacing: 12) {
            Text(action.headline)
                .font(.footnote)
                .foregroundStyle(Color.dealioTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let cta = action.cta, let onAction {
                Button { onAction(cta.target) } label: {
                    Text(cta.label)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(enabled ? Color.brandTeal : Color.dealioButtonDisabled,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(enabled ? .white : Color.dealioTextSecondary)
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
        )
    }
}
