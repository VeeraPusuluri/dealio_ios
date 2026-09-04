import SwiftUI

/// What a buyer can do with money that is not going into the home.
///
/// Three tabs, in the order a buyer arrives at them: what they hold now, what is
/// on offer, and the arithmetic that connects the two to their loan. Mirrors
/// Android's `ui/customer/finance/CustomerInvestmentsScreen.kt`.

private struct Investment: Identifiable {
    let name: String
    let category: String
    let returnMin: Double
    let returnMax: Double
    let lockInYears: Int
    let minAmount: Double
    let risk: String
    let detail: String
    var id: String { name }
}

private let opportunities: [Investment] = [
    Investment(name: "NRE Fixed Deposit", category: "Banking", returnMin: 6.5, returnMax: 7.5,
               lockInYears: 1, minAmount: 10_000, risk: "Very Low",
               detail: "Tax-free in India and fully repatriable. Start immediately."),
    Investment(name: "EV Charging Stations", category: "Infrastructure", returnMin: 15, returnMax: 22,
               lockInYears: 3, minAmount: 2_00_000, risk: "Medium",
               detail: "5M EVs, only 12,000 charging points. Revenue from per-charge fees."),
    Investment(name: "Retail Space Leasing", category: "Real Estate", returnMin: 8, returnMax: 12,
               lockInYears: 5, minAmount: 10_00_000, risk: "Low-Medium",
               detail: "Buy a small retail shop in a new township. Dealio manages tenants."),
    Investment(name: "Co-working Space", category: "Real Estate", returnMin: 10, returnMax: 15,
               lockInYears: 2, minAmount: 3_00_000, risk: "Medium",
               detail: "Co-working market growing 35% YoY in Hyderabad IT corridors."),
    Investment(name: "Solar Rooftop Commercial", category: "Energy", returnMin: 14, returnMax: 18,
               lockInYears: 5, minAmount: 1_50_000, risk: "Low",
               detail: "Earn from power units sold + government subsidy. Zero maintenance."),
    Investment(name: "Fractional CRE", category: "Real Estate", returnMin: 12, returnMax: 16,
               lockInYears: 3, minAmount: 5_00_000, risk: "Low-Medium",
               detail: "Own a fraction of Grade-A office space leased to MNCs."),
    Investment(name: "Student Housing / PG", category: "Real Estate", returnMin: 10, returnMax: 14,
               lockInYears: 2, minAmount: 8_00_000, risk: "Medium",
               detail: "40M students, 30% in PGs. Buy a PG unit, Dealio manages it."),
    Investment(name: "Cold Storage Units", category: "Infrastructure", returnMin: 16, returnMax: 20,
               lockInYears: 5, minAmount: 5_00_000, risk: "Medium-High",
               detail: "India wastes 40% of food. Government-backed cold-chain contracts."),
    Investment(name: "Medical Equipment Leasing", category: "Healthcare", returnMin: 15, returnMax: 18,
               lockInYears: 3, minAmount: 3_00_000, risk: "Medium",
               detail: "Lease equipment to clinics. Healthcare demand is recession-proof."),
    Investment(name: "Warehouse / Logistics", category: "Infrastructure", returnMin: 12, returnMax: 15,
               lockInYears: 5, minAmount: 10_00_000, risk: "Low",
               detail: "E-commerce needs 3x more warehouse space by 2028. 3–5 yr contracts."),
]

private enum InvestTab: String, CaseIterable { case active = "Active", planner = "Planner", calculator = "Calculator" }

struct CustomerInvestmentsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var deals = CustomerDealsModel()

    @State private var tab: InvestTab = .active
    @State private var monthlyInvest: Double = 50_000
    @State private var expectedReturn: Double = 15
    @State private var message: String?

    /// The offset arithmetic runs against the buyer's real loan when there is
    /// one, and against a worked example when there is not — the sliders are
    /// useless without something to offset.
    private var loanOutstanding: Double {
        deals.deals.compactMap(\.loanAmount).first ?? 1_58_00_000
    }
    private var yearsRemaining: Int {
        (deals.deals.compactMap(\.tenureMonths).first).map { max($0 / 12, 1) } ?? 19
    }
    private var monthlyEmi: Double {
        emiOf(principal: loanOutstanding, annualRate: 8.5, months: yearsRemaining * 12)
    }
    private var monthlyReturn: Double { monthlyInvest * expectedReturn / 100 / 12 }
    private var interestSaved: Double { monthlyReturn * 12 * Double(yearsRemaining) * 0.45 }
    private var yearsSaved: Double {
        monthlyEmi > 0 ? monthlyReturn / monthlyEmi * Double(yearsRemaining) * 0.8 : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            tabs
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch tab {
                    case .active: activeTab
                    case .planner: plannerTab
                    case .calculator: calculatorTab
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("Investments")
        .navigationBarTitleDisplayMode(.inline)
        .task { await deals.load(phone: auth.phone) }
        .alert("Investments", isPresented: Binding(get: { message != nil },
                                                   set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(InvestTab.allCases, id: \.self) { option in
                let on = tab == option
                Button { withAnimation(.snappy) { tab = option } } label: {
                    Text(option.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(on ? .white : Color.dealioTextSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(on ? Color.customerAccent : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: Active

    private var activeTab: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.customerAccent.opacity(0.12))
                Image(systemName: "wallet.bifold")
                    .font(.system(size: 26)).foregroundStyle(Color.customerAccent)
            }
            .frame(width: 54, height: 54)

            Text("No active investments yet")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dealioTextPrimary)
            Text("Once you start investing, your portfolio and returns appear here.")
                .font(.caption)
                .foregroundStyle(Color.dealioTextSecondary)
                .multilineTextAlignment(.center)

            Button { withAnimation(.snappy) { tab = .planner } } label: {
                Text("Explore investment planner")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.customerAccentBright, .customerAccent],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 18).padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    // MARK: Planner

    private var plannerTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Home loan at 8.5% → invest idle savings at 15% → net benefit 6.5%/yr → prepay loan → save 3–5 years of EMIs.")
                .font(.caption)
                .foregroundStyle(Color.dealioTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xF1F4F8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            ForEach(opportunities) { investment in card(investment) }

            VStack(alignment: .leading, spacing: 4) {
                Text("💡 Combine strategies")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dealioStatusAmber)
                Text("₹2L in EV Charging (18%) + ₹1L in NRE FD (7.25%) = 14.5% blended. Use returns to close your loan ~4 years early.")
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dealioStatusAmberBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button { message = "Our advisor will call you within 24 hours." } label: {
                Text("Talk to an investment advisor")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.customerAccentBright, .customerAccent],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func card(_ investment: Investment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(investment.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text(investment.category)
                        .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                }
                Spacer()
                Text("\(Int(investment.returnMin))–\(Int(investment.returnMax))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.customerAccent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.customerAccent.opacity(0.12), in: Capsule())
            }
            Text(investment.detail)
                .font(.caption)
                .foregroundStyle(Color.dealioTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 8) {
                chip("\(investment.lockInYears) yr lock-in")
                chip(investment.risk)
                chip("Min \(Money.inr(investment.minAmount))")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.dealioTextSecondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(hex: 0xF1F4F8), in: Capsule())
    }

    // MARK: Calculator

    private var calculatorTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Loan Offset Calculator")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text("Invest idle savings above your 8.5% loan rate and prepay your EMI.")
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            }

            slider("Monthly investment", Money.inr(monthlyInvest), $monthlyInvest, 5_000...2_00_000, 5_000)
            slider("Expected return", "\(Int(expectedReturn))% p.a.", $expectedReturn, 8...22, 1)

            VStack(spacing: 2) {
                kv("Loan outstanding", Money.inr(loanOutstanding))
                kv("Years remaining", "\(yearsRemaining) yrs")
                kv("Monthly EMI", Money.inr(monthlyEmi))
            }
            .padding(12)
            .background(Color(hex: 0xF1F4F8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("MONTHLY INVESTMENT RETURNS")
                    .font(.system(size: 10, weight: .bold)).tracking(0.8)
                    .foregroundStyle(Color.dealioTextSecondary)
                Text("\(Money.inr(monthlyReturn))/mo")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.customerAccent)
                Label("Loan closes \(String(format: "%.1f", yearsSaved)) years early", systemImage: "bolt")
                    .font(.footnote).foregroundStyle(Color.dealioTextPrimary)
                    .padding(.top, 6)
                Label("Save \(Money.inr(interestSaved)) in interest", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.footnote).foregroundStyle(Color.dealioTextPrimary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.customerAccent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func slider(_ label: String, _ value: String, _ binding: Binding<Double>,
                        _ range: ClosedRange<Double>, _ step: Double) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dealioTextSecondary)
                Spacer()
                Text(value).font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dealioTextPrimary)
            }
            Slider(value: binding, in: range, step: step).tint(.customerAccent)
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(Color.dealioTextSecondary)
            Spacer()
            Text(value).font(.caption.weight(.medium)).foregroundStyle(Color.dealioTextPrimary)
        }
        .padding(.vertical, 2)
    }
}
