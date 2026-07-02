import SwiftUI

struct CustomerProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var appLock: AppLockManager

    private var displayName: String { auth.user?.fullName ?? "Customer" }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 18) {
                    header(topInset: geo.safeAreaInsets.top)

                    // Home & finance
                    section("Home & finance") {
                        ProfileRow("My properties", "house.fill", .blue) { CustomerPropertyView() }
                        divider
                        ProfileRow("Home loans", "indianrupeesign.circle.fill", .green) { CustomerLoansView() }
                        divider
                        ProfileRow("EMI calculator", "function", .indigo) { CustomerEMIView() }
                        divider
                        ProfileRow("Loan eligibility", "checkmark.seal.fill", .teal) { CustomerLoanEligibilityView() }
                        divider
                        ProfileRow("Loan top-up", "plus.rectangle.on.folder.fill", .orange) { CustomerTopupView() }
                        divider
                        ProfileRow("Investments", "chart.line.uptrend.xyaxis", .purple) { CustomerInvestmentsView() }
                    }

                    // Documents & support
                    section("Documents & support") {
                        ProfileRow("Documents", "doc.text.fill", .blue) { CustomerDocumentsView() }
                        divider
                        ProfileRow("Conversations", "bubble.left.and.bubble.right.fill", .teal) { CustomerConversationsView() }
                        divider
                        ProfileRow("Possession tracker", "house.lodge.fill", .orange) { CustomerPossessionView() }
                        divider
                        ProfileRow("Snagging report", "wrench.and.screwdriver.fill", .red) { CustomerSnaggingView() }
                        divider
                        ProfileRow("Contact us", "headphones", .green) { CustomerContactView() }
                    }

                    // Security
                    section("Security") {
                        AppLockToggle()
                    }

                    Button(role: .destructive) { auth.logout() } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)

                    DealioLogo(markSize: 26, fontSize: 15)
                        .opacity(0.45)
                        .padding(.top, 4)
                }
                .padding(.bottom, 30)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .ignoresSafeArea(.container, edges: .top)
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: Header

    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: 14) {
            InitialsAvatar(name: displayName, tint: .dealioTealBright, size: 76)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))

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
        .padding(.top, topInset + 20)
        .padding(.bottom, 24)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
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

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 14)
                .cardSurface()
        }
        .padding(.horizontal)
    }

    private var divider: some View {
        Divider().padding(.leading, 42)
    }
}

/// A profile menu row with a coloured icon tile that pushes a destination.
private struct ProfileRow<Destination: View>: View {
    let label: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let destination: () -> Destination

    init(_ label: String, _ systemImage: String, _ tint: Color, @ViewBuilder destination: @escaping () -> Destination) {
        self.label = label; self.systemImage = systemImage; self.tint = tint; self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(tintGradient(tint), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }
}
