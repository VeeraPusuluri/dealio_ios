import Foundation

/// The offer a CP is posting about.
///
/// A caption is never just "here is a project" — it is "here is a project, on
/// these terms". The terms are what makes a buyer reply, so each offer type
/// carries its own headline, the concrete terms worth quoting, and what the CP
/// is offering to send back. Tone and platform only decide how that material is
/// dressed. Mirrors Android's `ui/cp/growth/OfferTypes.kt`.
///
/// Wording note: subvention and assured-return schemes are contractual, so the
/// copy points back at the agreement rather than promising a number. Nothing
/// here is commission-facing — these captions get forwarded to buyers.
struct OfferType: Identifiable, Hashable {
    let id: String
    let label: String
    /// The one-line summary shown beside the label in the picker.
    let keyFeature: String
    let emoji: String
    /// Caps headline that opens the offer block inside a caption.
    let badge: String
    /// The word a buyer is asked to DM or comment.
    let keyword: String
    let hashtag: String
    /// How the offer is framed for each audience — one per caption tone.
    let angles: OfferAngles
    /// Terms worth quoting. Two go into each caption, rotated by the seed.
    let points: [String]
    /// Noun phrases that complete "…and I'll send you ___".
    let asks: [String]

    func angle(_ tone: String) -> String {
        switch tone {
        case "investor": return angles.investor
        case "urgency": return angles.urgency
        default: return angles.lifestyle
        }
    }
}

/// The same offer, said three ways. Mirrors `captionTones`.
struct OfferAngles: Hashable {
    let lifestyle: String
    let investor: String
    let urgency: String
}

let offerTypes: [OfferType] = [
    OfferType(
        id: "otp", label: "OTP / Offer to Purchase", keyFeature: "Formal booking stage",
        emoji: "📝", badge: "OFFER TO PURCHASE", keyword: "BOOK", hashtag: "#HomeBooking",
        angles: OfferAngles(
            lifestyle: "If this is the one, the next step is simple — a signed offer to purchase puts the unit in your name while the paperwork catches up.",
            investor: "The offer to purchase locks the unit and the price while due diligence and the loan sanction run in parallel.",
            urgency: "A unit is only yours once the offer to purchase is in. Until then it stays on the open list."
        ),
        points: [
            "A signed OTP with the token amount blocks your chosen unit",
            "Price, floor and payment schedule are frozen at booking",
            "Allotment letter and agreement follow within the agreed window",
            "Bank sanction and legal checks can run alongside the booking",
        ],
        asks: [
            "the offer-to-purchase format along with the booking terms",
            "a walkthrough of the booking steps and what the token covers",
            "the current unit availability and the allotment timeline",
        ]
    ),
    OfferType(
        id: "prelaunch", label: "Pre-Launch", keyFeature: "Early discounted pricing",
        emoji: "🌱", badge: "PRE-LAUNCH PRICING", keyword: "PRELAUNCH", hashtag: "#PreLaunch",
        angles: OfferAngles(
            lifestyle: "Pre-launch is when you get the pick of the floors and the facing — before the crowd arrives.",
            investor: "Pre-launch is the lowest basis you will get on this project, and the delta shows up the day it goes public.",
            urgency: "Pre-launch pricing closes the day the project launches officially."
        ),
        points: [
            "Early-bird pricing ahead of the public launch",
            "First pick of floors, facing and unit numbers",
            "Pre-launch inventory is capped at a fixed number of units",
            "Payment terms are easier than the post-launch schedule",
        ],
        asks: [
            "the pre-launch price list before it is revised",
            "the pre-launch inventory and what is still open",
            "the pre-launch cost sheet and the expected launch price",
        ]
    ),
    OfferType(
        id: "launch", label: "Launch Offer", keyFeature: "Official release with promotions",
        emoji: "🚀", badge: "LAUNCH OFFER", keyword: "LAUNCH", hashtag: "#NewLaunch",
        angles: OfferAngles(
            lifestyle: "The project is officially open, and launch week is when the developer puts its best foot forward.",
            investor: "Launch pricing plus the launch-period benefits is the cleanest entry this project will offer.",
            urgency: "Launch offers run for a fixed window. After that the standard price list applies."
        ),
        points: [
            "Launch pricing across the released inventory",
            "Launch-period benefits on charges and add-ons as per the offer",
            "Model flat and site visits open through the launch window",
            "Full floor plan set and unit availability released together",
        ],
        asks: [
            "the launch price list and what the offer covers",
            "a launch-week site visit slot",
            "the launch offer sheet with the current availability",
        ]
    ),
    OfferType(
        id: "loan", label: "Loan-Linked", keyFeature: "Bank tie-ups, EMI holidays, subvention",
        emoji: "🏦", badge: "LOAN-LINKED PLAN", keyword: "EMI", hashtag: "#HomeLoan",
        angles: OfferAngles(
            lifestyle: "You can move on the home now and start the EMIs later — the loan plan is built for exactly that.",
            investor: "A subvention structure keeps the outflow low until possession, which changes the holding cost on the asset entirely.",
            urgency: "Subvention is tied to the current phase. It does not stay open through the project."
        ),
        points: [
            "Tie-ups with leading banks, with the project paperwork pre-approved",
            "EMI holiday or subvention until possession, as per the scheme terms",
            "Sanction support and documentation handled end to end",
            "Higher loan eligibility on an approved project file",
        ],
        asks: [
            "the EMI working and the list of approved banks",
            "the subvention terms and what you pay before possession",
            "a loan eligibility check and an in-principle sanction",
        ]
    ),
    OfferType(
        id: "clp", label: "Construction-Linked", keyFeature: "Pay as per construction milestones",
        emoji: "🏗", badge: "CONSTRUCTION-LINKED PLAN", keyword: "PLAN", hashtag: "#ConstructionLinked",
        angles: OfferAngles(
            lifestyle: "You pay as the building comes up. Nothing large falls due before the work behind it is done.",
            investor: "A CLP spreads the outflow across the build, so your capital stays deployed elsewhere until each slab is called.",
            urgency: "Every slab that goes up moves the price band — the schedule is cheapest at the stage the project is in today."
        ),
        points: [
            "Payments released against completed construction milestones",
            "Booking amount is a small share of the total ticket",
            "The milestone schedule is set out in the agreement upfront",
            "Progress is verifiable on site before each call comes",
        ],
        asks: [
            "the milestone-wise payment schedule",
            "the current construction status along with the payment plan",
            "a breakdown of how the outflow spreads across the build",
        ]
    ),
    OfferType(
        id: "downpayment", label: "Down Payment", keyFeature: "Large upfront payment, big discount",
        emoji: "💵", badge: "DOWN PAYMENT PLAN", keyword: "DISCOUNT", hashtag: "#DownPaymentPlan",
        angles: OfferAngles(
            lifestyle: "If you are in a position to pay upfront, this is the plan that gets you the most home for the money.",
            investor: "The down-payment plan carries the steepest discount on the list price — the best per-square-foot basis on offer.",
            urgency: "The down-payment discount is quoted against current phase pricing only."
        ),
        points: [
            "The highest discount on list price of any plan on offer",
            "Bulk of the consideration paid at booking, balance at possession",
            "Usually the lowest total cost once charges are added in",
            "Fewer payment calls to track through the build",
        ],
        asks: [
            "the down-payment cost sheet with the discount applied",
            "a comparison against the construction-linked plan",
            "the exact saving on the unit you are looking at",
        ]
    ),
    OfferType(
        id: "possession", label: "Possession-Linked", keyFeature: "Pay major portion at possession",
        emoji: "🔑", badge: "POSSESSION-LINKED PLAN", keyword: "KEYS", hashtag: "#PossessionLinked",
        angles: OfferAngles(
            lifestyle: "Book now, pay the bulk of it when you collect the keys — rent and EMI never have to overlap.",
            investor: "A possession-linked plan defers most of the outflow to handover, so the carrying cost until then is minimal.",
            urgency: "Possession-linked terms are released on limited inventory, not the full tower."
        ),
        points: [
            "A small share at booking, the major portion at possession",
            "Minimal outflow through the construction period",
            "Suits buyers currently paying rent elsewhere",
            "Payment falls due against handover, not against dates",
        ],
        asks: [
            "the possession-linked payment schedule",
            "a breakdown of what you pay before handover",
            "the units currently open on the possession-linked plan",
        ]
    ),
    OfferType(
        id: "assured", label: "Assured Rental / Buyback", keyFeature: "Guaranteed rental or resale value",
        emoji: "📈", badge: "ASSURED RETURN PLAN", keyword: "RETURNS", hashtag: "#AssuredReturns",
        angles: OfferAngles(
            lifestyle: "If you are not moving in straight away, the unit earns from handover instead of sitting idle.",
            investor: "Assured rental gives you a contracted yield from handover, with a buyback option written into the agreement.",
            urgency: "The assured-return inventory is a defined, limited set of units."
        ),
        points: [
            "Assured rental payouts from possession, as per the rental agreement",
            "Buyback option at a pre-agreed value within the agreed period",
            "Tenure, payout schedule and exit terms are set out in the agreement",
            "Leasing and tenant management handled by the operator",
        ],
        asks: [
            "the assured rental terms and the payout schedule",
            "the buyback clause and a summary of the agreement",
            "the yield working along with the agreement terms",
        ]
    ),
    OfferType(
        id: "festive", label: "Festive Offers", keyFeature: "Seasonal discounts, waived charges",
        emoji: "🎊", badge: "FESTIVE OFFER", keyword: "FESTIVE", hashtag: "#FestiveOffer",
        angles: OfferAngles(
            lifestyle: "The festive window is the nicest time to close on a home — and this year it comes with real savings attached.",
            investor: "Festive waivers come off charges, which means they come off the total cost and not just the headline price.",
            urgency: "The festive offer runs to a fixed date. After that the standard price list is back."
        ),
        points: [
            "Seasonal pricing on the released inventory",
            "Waivers on charges such as floor rise, club or registration, as per the offer",
            "Valid through the festive window only",
            "Spot-booking benefits during the offer period",
        ],
        asks: [
            "the festive offer sheet before the window closes",
            "what the festive waivers add up to on your unit",
            "the last date for the festive window and the offer terms",
        ]
    ),
]

func offerTypeOf(_ id: String?) -> OfferType? { offerTypes.first { $0.id == id } }
