import SwiftUI

/// An account type, with everything the auth screens need to render it.
///
/// Labels and colours mirror the web app's `roleLabels` / `roleColors`
/// (`stores/useAuthStore.ts`) and the Android app's `ui/auth/Roles.kt`, so a
/// Builder is the same teal on all three.
struct DealioRole: Identifiable, Hashable {
    /// Wire value — the backend expects the role uppercased.
    let value: String
    let label: String
    /// One-word form, for the tight sign-in pills.
    let shortLabel: String
    let tagline: String
    let color: Color
    let systemImage: String

    var id: String { value }
}

let RoleCustomer = DealioRole(
    value: "CUSTOMER", label: "Customer", shortLabel: "Customer",
    tagline: "Monitor your property journey",
    color: Color(hex: 0x16A34A), systemImage: "person"
)

let RoleCp = DealioRole(
    value: "CP", label: "Channel Partner", shortLabel: "Partner",
    tagline: "Track pipeline & commissions",
    color: Color(hex: 0xE87722), systemImage: "hand.raised"
)

let RoleBuilder = DealioRole(
    value: "BUILDER", label: "Builder", shortLabel: "Builder",
    tagline: "Manage inventory, RERA & leads",
    color: Color(hex: 0x0A7E8C), systemImage: "building.2"
)

let RoleBank = DealioRole(
    value: "BANK", label: "Bank Officer", shortLabel: "Bank",
    tagline: "Process loan cases faster",
    color: Color(hex: 0x2E5D8E), systemImage: "building.columns"
)

let RoleNri = DealioRole(
    value: "NRI", label: "NRI Buyer", shortLabel: "NRI",
    tagline: "Invest & manage remotely",
    color: Color(hex: 0xF5A623), systemImage: "globe"
)

let RoleAdmin = DealioRole(
    value: "ADMIN", label: "Admin", shortLabel: "Admin",
    tagline: "Platform administration",
    color: Color(hex: 0x6B3FA0), systemImage: "gearshape.2"
)

/// Roles that can open an account from the app — admins are provisioned, not
/// signed up.
let SignupRoles = [RoleCustomer, RoleCp, RoleBuilder, RoleBank, RoleNri]

/// Roles the sign-in picker offers. Administration is a web-portal job, so there
/// is no Admin pill — but see `KnownRoles`: admin still has to be *recognised*,
/// or an admin's number would sail through under whichever pill was selected.
let SigninRoles = SignupRoles

/// Every role this app can name, picker or not.
///
/// Admin is here and not in `SigninRoles` on purpose. `roleFor` returning `nil`
/// means "don't enforce", which is right for the backend roles the app has no
/// concept of — VENDOR, LANDOWNER, REFERRAL — but would be a hole for admin: the
/// pre-flight would stop objecting and an admin could sign in as a Customer.
let KnownRoles = SignupRoles + [RoleAdmin]

/// Looks up a role by its wire value. `nil` for the backend roles that have no
/// entry at all — callers must not block on those.
func roleFor(_ value: String?) -> DealioRole? {
    guard let wire = value?.trimmingCharacters(in: .whitespaces).uppercased(), !wire.isEmpty
    else { return nil }
    return KnownRoles.first { $0.value == wire }
}

extension DealioRole {
    /// Whether the sign-in picker can actually select this role.
    var isSignInOption: Bool { SigninRoles.contains(self) }
}

// MARK: - Colour on navy

extension Color {
    /// Role colours are picked to read on white cards, so the darker ones (bank
    /// blue, builder teal) go muddy on the navy hero.
    ///
    /// Raises the value and eases off the saturation rather than blending toward
    /// white: a straight blend lightens but also greys, which turned the bank's
    /// navy-blue into something that read as disabled. This keeps the hue intact.
    func onNavy() -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        else { return self }
        return Color(hue: hue, saturation: min(saturation, 0.62), brightness: max(brightness, 0.88))
    }
}

// MARK: - Portal accents

/// The colour a portal's hero is lit with.
///
/// Every portal opened on the same navy band, so a buyer's home, a partner's
/// home and a builder's home were the same screen with different words on it.
/// Sign-in solves this by tinting its hero with the role's own colour; these are
/// those same tints, carried past the sign-in card into the portal behind it —
/// so the colour someone signs in with is the colour they then work in.

/// Buyer green — `RoleCustomer`'s colour, lifted for legibility on navy.
let CustomerHeroAccent = RoleCustomer.color.onNavy()

/// Partner orange — `RoleCp`'s colour, same treatment.
let CpHeroAccent = RoleCp.color.onNavy()

/// Builder blue.
///
/// Not the builder's own teal: against the buyer's green it read as the same
/// portal at a glance, and telling the portals apart is the entire point of
/// tinting them. This is the blue the bank role already carries on sign-in,
/// which is the one cool hue in the palette that is nobody else's.
let BuilderHeroAccent = Color(hex: 0x2E5D8E).onNavy()

/// The tint a role's *sign-in* hero glows with.
///
/// Sign-in and the portal have to agree, or the promise breaks at the moment it
/// is made: a builder picked a teal card and landed on a blue home. Roles with a
/// portal answer with the portal's accent; the rest — bank, NRI — keep their own
/// colour lifted for navy.
///
/// The role *pills* deliberately still use `DealioRole.color`: the builder's
/// blue hero comes from the bank's colour, so painting the pill with it too
/// would put two identical blues in a picker whose whole job is telling roles
/// apart.
func heroAccentFor(_ role: DealioRole) -> Color {
    switch role.value {
    case RoleCustomer.value: return CustomerHeroAccent
    case RoleCp.value: return CpHeroAccent
    case RoleBuilder.value: return BuilderHeroAccent
    default: return role.color.onNavy()
    }
}

/// The accent for whichever portal is on screen, so a screen paints the right
/// tint without being told which portal it belongs to.
private struct HeroAccentKey: EnvironmentKey {
    static let defaultValue = Color.dealioTealBright
}

extension EnvironmentValues {
    var heroAccent: Color {
        get { self[HeroAccentKey.self] }
        set { self[HeroAccentKey.self] = newValue }
    }
}
