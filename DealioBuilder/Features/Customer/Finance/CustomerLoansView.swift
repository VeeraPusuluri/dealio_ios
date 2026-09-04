import SwiftUI

/// The buyer's home loans — the tools above, the applications below.
///
/// The two calculators sit at the top because most visits are someone working
/// out what they can afford, not checking an application they already filed.
/// Mirrors Android's `ui/customer/loan/LoansScreen.kt`.

private let loanStages = ["Applied", "Under Review", "Sanctioned", "Disbursed"]

struct CustomerLoansView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CustomerDealsModel()


    /// Only the deals that actually have a loan case behind them.
    private var loans: [CustomerDeal] { model.deals.filter { $0.loanCaseId != nil } }

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.deals.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await model.load(phone: auth.phone) } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            NavigationLink(value: PortalRoute.customerEMI) {
                                toolTile("EMI Calculator", "Charts & full schedule", "function")
                            }
                            .buttonStyle(.plain)
                            NavigationLink(value: PortalRoute.customerEligibility) {
                                toolTile("Eligibility", "Compare bank offers", "building.columns")
                            }
                            .buttonStyle(.plain)
                        }

                        SectionLabel("Your applications").padding(.top, 4)

                        if loans.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.dealioTextSecondary)
                                Text("No loan applications yet")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.dealioTextPrimary)
                                Text("Tap Apply to get matched with the best home-loan offers.")
                                    .font(.caption)
                                    .foregroundStyle(Color.dealioTextSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .cardSurface(cornerRadius: 16)
                        } else {
                            ForEach(loans) { loan in loanCard(loan) }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await model.load(phone: auth.phone) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("Home loans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: PortalRoute.customerLoanApply(projectId: nil, builderId: nil)) {
                    Label("Apply", systemImage: "plus")
                }
            }
        }
        .task { await model.load(phone: auth.phone) }
    }

    private func toolTile(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.customerAccent.opacity(0.12))
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.customerAccent)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Color.dealioTextPrimary)
                Text(subtitle).font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 16)
    }

    private func loanCard(_ loan: CustomerDeal) -> some View {
        // The stage the bank has reached. -1 for a status the ladder doesn't
        // know, which leaves every segment unfilled rather than filling them all.
        let current = loanStages.firstIndex { $0.caseInsensitiveCompare(loan.loanStatus ?? "") == .orderedSame } ?? -1
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(loan.projectName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text(Fmt.shortRupee(loan.loanAmount ?? 0))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.customerAccent)
                }
                Spacer()
                StatusBadge(text: loan.loanStatus ?? "Applied", color: statusColor(loan.loanStatus))
            }

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(Array(loanStages.enumerated()), id: \.offset) { index, _ in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(index <= current ? Color.customerAccent : Color.dealioCardBorder)
                            .frame(height: 5)
                    }
                }
                HStack {
                    ForEach(loanStages, id: \.self) { stage in
                        Text(stage)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.dealioTextSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            if loan.interestRate != nil || loan.tenureMonths != nil {
                Text([loan.interestRate.map { "\(Fmt.percent($0)) p.a." },
                      loan.tenureMonths.map { "\($0 / 12) yr tenure" }]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 16)
    }
}
