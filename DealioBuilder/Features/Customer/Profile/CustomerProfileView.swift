import SwiftUI

/// Everything the profile menu can open.
///
/// The rows used to be `NavigationLink { CustomerLoansView() }`. Outside a
/// `List`, SwiftUI builds that trailing closure for **every** row as soon as the
/// page renders — so opening Profile constructed thirteen screens at once, each
/// allocating its own `@StateObject` model, and every tap then waited behind
/// that work. Routing by value builds exactly one screen, when it is pushed.
enum CustomerProfileRoute: Hashable, CaseIterable {
    case properties, loans, emi, eligibility, topup, investments
    case documents, conversations, possession, snagging, contact, notifications, meetups

    var title: String {
        switch self {
        case .properties: return "My properties"
        case .loans: return "Home loans"
        case .emi: return "EMI calculator"
        case .eligibility: return "Loan eligibility"
        case .topup: return "Loan top-up"
        case .investments: return "Investments"
        case .documents: return "Documents"
        case .conversations: return "Conversations"
        case .possession: return "Possession tracker"
        case .snagging: return "Snagging report"
        case .contact: return "Contact us"
        case .notifications: return "Notifications"
        case .meetups: return "Meetups near you"
        }
    }

    var icon: String {
        switch self {
        case .properties: return "house.fill"
        case .loans: return "indianrupeesign.circle.fill"
        case .emi: return "function"
        case .eligibility: return "checkmark.seal.fill"
        case .topup: return "plus.rectangle.on.folder.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .documents: return "doc.text.fill"
        case .conversations: return "bubble.left.and.bubble.right.fill"
        case .possession: return "house.lodge.fill"
        case .snagging: return "wrench.and.screwdriver.fill"
        case .contact: return "headphones"
        case .notifications: return "bell.fill"
        case .meetups: return "person.3.fill"
        }
    }

    var tint: Color {
        switch self {
        case .properties: return .blue
        case .loans: return .green
        case .emi: return .indigo
        case .eligibility: return .teal
        case .topup: return .orange
        case .investments: return .purple
        case .documents: return .blue
        case .conversations: return .teal
        case .possession: return .orange
        case .snagging: return .red
        case .contact: return .green
        case .notifications: return .pink
        case .meetups: return .purple
        }
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .properties: CustomerPropertyView()
        case .loans: CustomerLoansView()
        case .emi: CustomerEMIView()
        case .eligibility: CustomerLoanEligibilityView()
        case .topup: CustomerTopupView()
        case .investments: CustomerInvestmentsView()
        case .documents: CustomerDocumentsView()
        case .conversations: CustomerConversationsView()
        case .possession: CustomerPossessionView()
        case .snagging: CustomerSnaggingView()
        case .contact: CustomerContactView()
        case .notifications: CustomerNotificationsView()
        case .meetups: CustomerMeetupsView()
        }
    }

    static let homeAndFinance: [CustomerProfileRoute] =
        [.properties, .loans, .emi, .eligibility, .topup, .investments]
    static let documentsAndSupport: [CustomerProfileRoute] =
        [.documents, .conversations, .possession, .snagging, .contact, .notifications, .meetups]
}

struct CustomerProfileView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var appLock: AppLockManager

    private var displayName: String { auth.user?.fullName ?? "Customer" }

    var body: some View {
        NavigationStack(path: router.path(4)) {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    section("Home & finance", routes: CustomerProfileRoute.homeAndFinance)
                    section("Documents & support", routes: CustomerProfileRoute.documentsAndSupport)

                    // Security
                    sectionShell("Security") { AppLockToggle() }

                    Button(role: .destructive) { auth.logout() } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .padding(.horizontal)

                    DealioLogo(markSize: 26, fontSize: 15)
                        .opacity(0.45)
                        .padding(.top, 4)
                }
                .padding(.bottom, 30)
            }
            .dealioPageBackground(.customerSurface)
            .heroScrollEdges()
            .navigationDestination(for: CustomerProfileRoute.self) { $0.destination }
            .portalDestinations()
            .navigationBarHidden(true)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            AccountAvatar(size: 76, tint: .customerAccentBright)

            VStack(spacing: 3) {
                Text(displayName)
                    .font(.title3.weight(.bold)).foregroundStyle(.white)
                if let phone = auth.user?.phone {
                    Text(phone).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
            }

            // Email + account chips
            HStack(spacing: 8) {
                if let email = auth.user?.email, !email.isEmpty {
                    chip("envelope.fill", email)
                }
                chip("person.fill", (auth.user?.role ?? "Customer").capitalized)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SafeArea.top + 20)
        .padding(.bottom, 24)
        .padding(.horizontal, 20)
        .background(BrandHeaderBackground())
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28,
                                          style: .continuous))
    }

    private func chip(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).font(.caption2)
            Text(text).font(.caption.weight(.medium)).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.white.opacity(0.15), in: Capsule())
        .foregroundStyle(.white)
    }

    // MARK: Section helpers

    private func section(_ title: String, routes: [CustomerProfileRoute]) -> some View {
        sectionShell(title) {
            ForEach(Array(routes.enumerated()), id: \.element) { index, route in
                NavigationLink(value: route) { ProfileRowLabel(route: route) }
                    .buttonStyle(.plain)
                if index < routes.count - 1 {
                    Divider().padding(.leading, 42)
                }
            }
        }
    }

    private func sectionShell<Content: View>(_ title: String,
                                             @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.dealioTextSecondary)
                .tracking(0.6)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 14)
                .cardSurface()
        }
        .padding(.horizontal)
    }
}

/// The visual half of a profile menu row. Separate from the link so the row can
/// be pushed by value.
private struct ProfileRowLabel: View {
    let route: CustomerProfileRoute

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: route.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tintGradient(route.tint),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(route.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.dealioTextPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dealioTextSecondary.opacity(0.6))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
