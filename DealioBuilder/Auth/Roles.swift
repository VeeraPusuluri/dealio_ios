import SwiftUI

/// An account type, with everything the auth screens need to render it.
///
/// Labels and colours mirror the web app's `roleLabels` / `roleColors` and
/// Android's `ui/auth/Roles.kt`, so a Builder is the same teal on every client.
struct DealioRole: Identifiable, Hashable {
    /// Wire value — the backend expects the role uppercased.
    let value: String
    let label: String
    /// One-word form, for the tight sign-in pills.
    let shortLabel: String
    let tagline: String
    let color: Color
    let icon: String

    var id: String { value }
}

enum Roles {
    static let customer = DealioRole(
        value: "CUSTOMER", label: "Customer", shortLabel: "Customer",
        tagline: "Monitor your property journey",
        // Brand gold, not a buyer green: the pill a buyer picks here has to be
        // the colour the portal then opens in.
        color: .customerAccentBright, icon: "person"
    )
    static let cp = DealioRole(
        value: "CP", label: "Channel Partner", shortLabel: "Partner",
        tagline: "Track pipeline & commissions",
        color: Color(hex: 0xE87722), icon: "hands.sparkles"
    )
    static let builder = DealioRole(
        value: "BUILDER", label: "Builder", shortLabel: "Builder",
        tagline: "Manage inventory, RERA & leads",
        color: Color(hex: 0x0A7E8C), icon: "building.2"
    )
    static let bank = DealioRole(
        value: "BANK", label: "Bank Officer", shortLabel: "Bank",
        tagline: "Process loan cases faster",
        color: Color(hex: 0x2E5D8E), icon: "building.columns"
    )
    static let nri = DealioRole(
        value: "NRI", label: "NRI Buyer", shortLabel: "NRI",
        tagline: "Invest & manage remotely",
        color: Color(hex: 0xF5A623), icon: "globe"
    )
    static let admin = DealioRole(
        value: "ADMIN", label: "Admin", shortLabel: "Admin",
        tagline: "Platform administration",
        color: Color(hex: 0x6B3FA0), icon: "gearshape.2"
    )

    /// Roles that can open an account from the app — admins are provisioned.
    static let signup = [customer, cp, builder, bank, nri]

    /// Roles the sign-in picker offers. Administration is a web-portal job, so
    /// there is no Admin pill — but see `known`: admin still has to be
    /// *recognised*, or an admin's number would sail through under whichever
    /// pill was selected.
    static let signin = signup

    /// Every role this app can name, picker or not.
    static let known = signup + [admin]

    /// Look up a role by its wire value. nil for the backend roles that have no
    /// entry at all (VENDOR, LANDOWNER, REFERRAL) — callers must not block on
    /// those, or a legitimate account is locked out.
    static func forValue(_ value: String?) -> DealioRole? {
        guard let wire = value?.trimmingCharacters(in: .whitespaces).uppercased(), !wire.isEmpty else { return nil }
        return known.first { $0.value == wire }
    }
}

/// A row of role pills — the same control on sign-in and sign-up.
///
/// The selected pill fills with the role's own colour, which is the colour the
/// portal it opens is themed in: picking "Customer" here previews the gold the
/// buyer portal wears, so the choice reads as a destination and not a form field.
struct RoleSelector: View {
    let roles: [DealioRole]
    @Binding var selection: String
    var showTagline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(roles) { role in
                    pill(role)
                }
            }
            if showTagline, let picked = Roles.forValue(selection) {
                HStack(spacing: 5) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(picked.color)
                    Text(picked.tagline)
                        .font(.caption)
                        .foregroundStyle(Color.dealioTextSecondary)
                }
                .id(picked.value)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: selection)
    }

    private func pill(_ role: DealioRole) -> some View {
        let on = role.value == selection
        return Button {
            selection = role.value
        } label: {
            HStack(spacing: 6) {
                Image(systemName: role.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(role.shortLabel)
                    .font(.subheadline.weight(on ? .bold : .medium))
            }
            .foregroundStyle(on ? .white : Color.dealioTextSecondary)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(
                on ? AnyShapeStyle(LinearGradient(colors: [role.color.opacity(0.92), role.color],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                   : AnyShapeStyle(Color.dealioFieldFill),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(on ? Color.clear : Color.dealioCardBorder, lineWidth: 1)
            )
            .shadow(color: on ? role.color.opacity(0.35) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(role.label)
        .accessibilityHint(role.tagline)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
