import SwiftUI

struct CustomerProfileView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        InitialsAvatar(name: auth.user?.fullName, size: 72)
                        VStack(spacing: 2) {
                            Text(auth.user?.fullName ?? "Customer").font(.title3.weight(.bold))
                            if let phone = auth.user?.phone {
                                Text(phone).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 16)

                    // Details
                    VStack(spacing: 0) {
                        InfoRow(label: "Email", value: auth.user?.email ?? "—")
                        InfoRow(label: "Account", value: (auth.user?.role ?? "Customer").capitalized)
                    }
                    .padding(.horizontal, 16)
                    .cardSurface()
                    .padding(.horizontal)

                    // Home & finance
                    VStack(spacing: 0) {
                        NavRow("My properties", "house") { CustomerPropertyView() }
                        NavRow("Home loans", "indianrupeesign.circle") { CustomerLoansView() }
                        NavRow("EMI calculator", "function") { CustomerEMIView() }
                        NavRow("Loan eligibility", "checkmark.seal") { CustomerLoanEligibilityView() }
                        NavRow("Loan top-up", "plus.rectangle.on.folder") { CustomerTopupView() }
                        NavRow("Investments", "chart.line.uptrend.xyaxis") { CustomerInvestmentsView() }
                    }
                    .padding(.horizontal, 16).cardSurface().padding(.horizontal)

                    // Documents & support
                    VStack(spacing: 0) {
                        NavRow("Documents", "doc.text") { CustomerDocumentsView() }
                        NavRow("Conversations", "bubble.left.and.bubble.right") { CustomerConversationsView() }
                        NavRow("Possession tracker", "house.lodge") { CustomerPossessionView() }
                        NavRow("Snagging report", "wrench.and.screwdriver") { CustomerSnaggingView() }
                        NavRow("Contact us", "headphones") { CustomerContactView() }
                    }
                    .padding(.horizontal, 16).cardSurface().padding(.horizontal)
                    // (helper NavRow + remaining screens defined in this batch)

                    Button(role: .destructive) { auth.logout() } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)

                    DealioLogo(markSize: 28, fontSize: 16)
                        .opacity(0.5)
                        .padding(.top, 8)
                }
                .padding(.bottom, 30)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.vertical, 13)
        .overlay(Divider(), alignment: .bottom)
    }
}

/// A profile menu row that pushes a destination.
struct NavRow<Destination: View>: View {
    let label: String
    let systemImage: String
    @ViewBuilder let destination: () -> Destination

    init(_ label: String, _ systemImage: String, @ViewBuilder destination: @escaping () -> Destination) {
        self.label = label; self.systemImage = systemImage; self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage).foregroundStyle(.brandTeal).frame(width: 24)
                Text(label).font(.subheadline).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 13)
            .overlay(Divider(), alignment: .bottom)
        }
    }
}
