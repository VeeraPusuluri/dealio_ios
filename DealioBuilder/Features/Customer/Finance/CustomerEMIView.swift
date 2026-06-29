import SwiftUI
import Charts

private struct YearBreak: Identifiable {
    let year: Int
    let principal: Double
    let interest: Double
    var id: Int { year }
}

struct CustomerEMIView: View {
    @State private var amount: Double = 50_00_000
    @State private var rate: Double = 8.65
    @State private var tenure: Double = 20

    private var months: Int { Int(tenure) * 12 }
    private var monthlyRate: Double { rate / 12 / 100 }
    private var emi: Double {
        let n = Double(months)
        return monthlyRate > 0 ? amount * monthlyRate * pow(1 + monthlyRate, n) / (pow(1 + monthlyRate, n) - 1) : amount / n
    }
    private var totalPayable: Double { emi * Double(months) }
    private var totalInterest: Double { max(totalPayable - amount, 0) }
    private var principalPct: Int { totalPayable > 0 ? Int(amount / totalPayable * 100) : 0 }

    private var yearly: [YearBreak] {
        var balance = amount
        return (1...max(Int(tenure), 1)).map { y in
            var p = 0.0, i = 0.0
            for _ in 0..<12 {
                let interest = balance * monthlyRate
                let principal = emi - interest
                p += principal; i += interest; balance -= principal
            }
            return YearBreak(year: y, principal: p, interest: i)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // EMI hero
                VStack(alignment: .leading, spacing: 4) {
                    Text("MONTHLY EMI").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.7))
                    Text(Money.inr(emi)).font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("per month for \(Int(tenure)) years").font(.caption).foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                .background(LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 12) {
                    StatCard(title: "Total Payable", value: Money.inr(totalPayable), systemImage: "banknote", tint: .brandTeal)
                    StatCard(title: "Total Interest", value: Money.inr(totalInterest), systemImage: "arrow.down.right.circle", tint: .orange)
                }

                // Inputs
                VStack(spacing: 14) {
                    slider("Loan amount", Money.inr(amount), $amount, 10_00_000...10_00_00_000, 50_000)
                    slider("Interest rate", String(format: "%.2f%%", rate), $rate, 7...15, 0.05)
                    slider("Loan tenure", "\(Int(tenure)) yr", $tenure, 5...30, 1)
                    Divider()
                    HStack {
                        Chart {
                            SectorMark(angle: .value("Principal", amount), innerRadius: .ratio(0.6)).foregroundStyle(Color.brandTeal)
                            SectorMark(angle: .value("Interest", totalInterest), innerRadius: .ratio(0.6)).foregroundStyle(.orange)
                        }
                        .frame(width: 110, height: 110)
                        VStack(alignment: .leading, spacing: 8) {
                            legend(.brandTeal, "Principal", "\(principalPct)%")
                            legend(.orange, "Interest", "\(100 - principalPct)%")
                        }
                        Spacer()
                    }
                }
                .padding(16).cardSurface()

                // Breakdown chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Principal vs interest by year").font(.subheadline.weight(.bold))
                    Chart(yearly) { row in
                        BarMark(x: .value("Year", "Y\(row.year)"), y: .value("Principal", row.principal)).foregroundStyle(Color.brandTeal)
                        BarMark(x: .value("Year", "Y\(row.year)"), y: .value("Interest", row.interest)).foregroundStyle(.orange)
                    }
                    .frame(height: 200)
                    .chartLegend(.hidden)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
            }
            .padding()
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("EMI Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func slider(_ label: String, _ value: String, _ binding: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(label).font(.caption).foregroundStyle(.secondary); Spacer(); Text(value).font(.caption.weight(.bold)) }
            Slider(value: binding, in: range, step: step).tint(.brandTeal)
        }
    }
    private func legend(_ color: Color, _ label: String, _ pct: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 11, height: 11)
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            Text(pct).font(.caption.weight(.bold))
        }
    }
}
