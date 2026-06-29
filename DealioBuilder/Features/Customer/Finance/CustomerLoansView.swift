import SwiftUI

private let loanStages = ["Applied", "Under Review", "Sanctioned", "Disbursed"]

struct CustomerLoansView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CustomerDealsModel()

    private var loans: [CustomerDeal] { model.deals.filter { ($0.loanStatus ?? "").isEmpty == false } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Tools
                HStack(spacing: 12) {
                    tool("EMI Calculator", "function") { CustomerEMIView() }
                    tool("Eligibility", "checkmark.seal") { CustomerLoanEligibilityView() }
                }

                if model.loading {
                    ProgressView().padding(.top, 20)
                } else {
                    Text("Your applications").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    if loans.isEmpty {
                        ContentUnavailableView("No loan applications yet", systemImage: "building.columns",
                            description: Text("Apply from a project to get matched with the best home-loan offers."))
                    } else {
                        ForEach(loans) { loan in loanCard(loan) }
                    }
                }
            }
            .padding()
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Home Loans")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(phone: auth.phone) }
        .refreshable { await model.load(phone: auth.phone) }
    }

    private func tool<D: View>(_ title: String, _ icon: String, @ViewBuilder dest: @escaping () -> D) -> some View {
        NavigationLink { dest() } label: {
            VStack(alignment: .leading, spacing: 8) {
                IconBadge(systemImage: icon, tint: .brandTeal)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14).cardSurface()
        }.buttonStyle(.plain)
    }

    private func loanCard(_ loan: CustomerDeal) -> some View {
        let current = loanStages.firstIndex { $0.caseInsensitiveCompare(loan.loanStatus ?? "") == .orderedSame } ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(loan.projectName ?? "Loan").font(.headline)
                Spacer()
                StatusBadge(text: loan.loanStatus ?? "Applied", color: statusColor(loan.loanStatus))
            }
            HStack(spacing: 4) {
                ForEach(loanStages.indices, id: \.self) { i in
                    Capsule().fill(i <= current ? Color.brandTeal : Color(.tertiarySystemFill)).frame(height: 5)
                }
            }
            HStack {
                ForEach(loanStages, id: \.self) { Text($0).font(.system(size: 9)).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }
}
