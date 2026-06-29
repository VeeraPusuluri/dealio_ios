import SwiftUI

private struct Opportunity: Identifiable {
    let name: String; let category: String; let returnMin: Int; let returnMax: Int
    let lockIn: Int; let minAmount: Double; let risk: String; let desc: String
    var id: String { name }
}
private let opportunities = [
    Opportunity(name: "NRE Fixed Deposit", category: "Banking", returnMin: 6, returnMax: 7, lockIn: 1, minAmount: 10000, risk: "Very Low", desc: "Tax-free in India and fully repatriable. Start immediately."),
    Opportunity(name: "EV Charging Stations", category: "Infrastructure", returnMin: 15, returnMax: 22, lockIn: 3, minAmount: 200000, risk: "Medium", desc: "5M EVs, only 12,000 charging points. Revenue from per-charge fees."),
    Opportunity(name: "Solar Rooftop Commercial", category: "Energy", returnMin: 14, returnMax: 18, lockIn: 5, minAmount: 150000, risk: "Low", desc: "Earn from power units sold + government subsidy. Zero maintenance."),
    Opportunity(name: "Fractional CRE", category: "Real Estate", returnMin: 12, returnMax: 16, lockIn: 3, minAmount: 500000, risk: "Low-Medium", desc: "Own a fraction of Grade-A office space leased to MNCs."),
    Opportunity(name: "Co-working Space", category: "Real Estate", returnMin: 10, returnMax: 15, lockIn: 2, minAmount: 300000, risk: "Medium", desc: "Co-working market growing 35% YoY in IT corridors."),
    Opportunity(name: "Warehouse / Logistics", category: "Infrastructure", returnMin: 12, returnMax: 15, lockIn: 5, minAmount: 1000000, risk: "Low", desc: "E-commerce needs 3× more warehouse space by 2028."),
]

struct CustomerInvestmentsView: View {
    @State private var tab = 0
    @State private var monthlyInvest: Double = 50000
    @State private var expectedReturn: Double = 15

    private let loanOutstanding = 1_58_00_000.0, yearsRemaining = 19.0, monthlyEmi = 1_38_500.0
    private var monthlyReturn: Double { monthlyInvest * expectedReturn / 100 / 12 }
    private var interestSaved: Double { monthlyReturn * 12 * yearsRemaining * 0.45 }
    private var yearsSaved: Double { monthlyReturn > 0 ? monthlyReturn / monthlyEmi * yearsRemaining * 0.8 : 0 }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Active").tag(0); Text("Planner").tag(1); Text("Calculator").tag(2)
            }.pickerStyle(.segmented).padding()

            ScrollView {
                VStack(spacing: 14) {
                    switch tab {
                    case 0:
                        ContentUnavailableView {
                            Label("No active investments yet", systemImage: "wallet.bifold")
                        } description: {
                            Text("Once you start investing, your portfolio and returns appear here.")
                        } actions: {
                            Button("Explore planner") { tab = 1 }.buttonStyle(.borderedProminent).tint(.brandTeal)
                        }
                        .padding(.top, 30)
                    case 1:
                        Text("Home loan at 8.5% → invest idle savings at 15% → net benefit 6.5%/yr → prepay → save 3–5 years of EMIs.")
                            .font(.caption).foregroundStyle(.secondary).padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        ForEach(opportunities) { o in card(o) }
                    default:
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Loan Offset Calculator").font(.headline)
                            HStack { Text("Monthly investment").font(.caption).foregroundStyle(.secondary); Spacer(); Text(Money.inr(monthlyInvest)).font(.caption.weight(.bold)) }
                            Slider(value: $monthlyInvest, in: 5000...200000, step: 5000).tint(.brandTeal)
                            HStack { Text("Expected return").font(.caption).foregroundStyle(.secondary); Spacer(); Text("\(Int(expectedReturn))% p.a.").font(.caption.weight(.bold)) }
                            Slider(value: $expectedReturn, in: 8...22, step: 1).tint(.brandTeal)
                            Divider()
                            Text("MONTHLY RETURNS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                            Text("\(Money.inr(monthlyReturn))/mo").font(.title.weight(.bold)).foregroundStyle(.brandTeal)
                            Label("Loan closes \(yearsSaved, specifier: "%.1f") years early", systemImage: "bolt.fill").font(.subheadline).foregroundStyle(.primary)
                            Label("Save \(Money.inr(interestSaved)) in interest", systemImage: "chart.line.uptrend.xyaxis").font(.subheadline).foregroundStyle(.primary)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Investments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ o: Opportunity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(o.name).font(.subheadline.weight(.bold))
                    Text(o.category).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(o.returnMin)–\(o.returnMax)%").font(.subheadline.weight(.bold)).foregroundStyle(.brandTeal)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Color.brandTeal.opacity(0.12), in: Capsule())
            }
            Text(o.desc).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                chip("\(o.lockIn) yr lock-in"); chip(o.risk); chip("Min \(Money.inr(o.minAmount))")
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }
    private func chip(_ t: String) -> some View {
        Text(t).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 4).background(Color(.tertiarySystemFill), in: Capsule())
    }
}
