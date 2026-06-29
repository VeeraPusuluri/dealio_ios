import SwiftUI

@MainActor
final class BuilderLoansModel: ObservableObject {
    @Published var loans: [BuilderLoan] = []
    @Published var loading = true
    @Published var error: String?

    func load(builderId: Int) async {
        loading = loans.isEmpty
        error = nil
        do {
            loans = try await APIClient.shared.get("/builder/\(builderId)/loans")
        } catch { self.error = authMessage(error) }
        loading = false
    }
}

private let loanStages = ["Applied", "Documents Submitted", "Under Review", "Sanctioned", "Disbursed"]

struct BuilderLoansView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderLoansModel()

    var body: some View {
        Group {
            if model.loading {
                ProgressView()
            } else if let error = model.error {
                ErrorBanner(message: error).padding()
            } else if model.loans.isEmpty {
                ContentUnavailableView("No loan cases", systemImage: "creditcard",
                    description: Text("Home-loan applications on your deals appear here."))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(model.loans) { loan in LoanCard(loan: loan) }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Loan Cases")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}

private struct LoanCard: View {
    let loan: BuilderLoan
    private var stageIndex: Int { loanStages.firstIndex { $0.caseInsensitiveCompare(loan.status ?? "") == .orderedSame } ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.customerName ?? "Applicant").font(.headline)
                    Text(loan.projectName ?? "—").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: loan.status ?? "Applied", color: statusColor(loan.status))
            }
            Text(Money.inr(loan.loanAmount)).font(.title3.weight(.bold)).foregroundStyle(.brandTeal)

            // Progress bar
            GeometryReader { geo in
                let progress = CGFloat(stageIndex) / CGFloat(max(loanStages.count - 1, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill)).frame(height: 6)
                    Capsule().fill(LinearGradient.brand).frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            if let extra = [loan.bank, loan.interestRate.map { "\($0)%" }, loan.tenureMonths.map { "\($0/12) yr" }]
                .compactMap({ $0 }).joined(separator: " · ") as String?, !extra.isEmpty {
                Text(extra).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }
}
