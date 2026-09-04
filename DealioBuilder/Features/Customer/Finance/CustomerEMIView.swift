import SwiftUI

/// What a home loan actually costs, month by month.
///
/// The three inputs are sliders rather than fields because a buyer is exploring
/// rather than entering known numbers — the point is to see the EMI move.
/// Mirrors Android's `ui/customer/loan/EmiCalculatorScreen.kt`.

private struct YearBreak: Identifiable {
    let year: Int
    let principal: Double
    let interest: Double
    var id: Int { year }
}

private struct SchedRow: Identifiable {
    let month: Int
    let principal: Double
    let interest: Double
    let outstanding: Double
    var id: Int { month }
}

/// The standard amortising EMI. A zero rate divides evenly rather than dividing
/// by zero — a buyer dragging the slider to the floor should see a number.
func emiOf(principal: Double, annualRate: Double, months: Int) -> Double {
    guard months > 0 else { return 0 }
    let r = annualRate / 12 / 100
    guard r > 0 else { return principal / Double(months) }
    let growth = pow(1 + r, Double(months))
    return principal * r * growth / (growth - 1)
}

private func buildSchedule(amount: Double, monthlyRate: Double, emi: Double, months: Int) -> [SchedRow] {
    var outstanding = amount
    return (1...max(months, 1)).map { month in
        let interest = outstanding * monthlyRate
        let principal = emi - interest
        outstanding = max(outstanding - principal, 0)
        return SchedRow(month: month, principal: principal, interest: interest, outstanding: outstanding)
    }
}

private func buildYearly(amount: Double, monthlyRate: Double, emi: Double, years: Int) -> [YearBreak] {
    var balance = amount
    return (1...max(years, 1)).map { year in
        var principal = 0.0
        var interest = 0.0
        for _ in 0..<12 {
            let interestPart = balance * monthlyRate
            let principalPart = emi - interestPart
            principal += principalPart
            interest += interestPart
            balance -= principalPart
        }
        return YearBreak(year: year, principal: principal, interest: interest)
    }
}

private enum BreakdownTab: String, CaseIterable { case chart = "Chart", schedule = "Schedule" }

struct CustomerEMIView: View {
    @State private var amount: Double = 50_00_000
    @State private var rate: Double = 8.65
    @State private var tenure: Double = 20
    @State private var tab: BreakdownTab = .chart

    private var months: Int { max(Int(tenure * 12), 1) }
    private var monthlyRate: Double { rate / 12 / 100 }
    private var emi: Double { emiOf(principal: amount, annualRate: rate, months: months) }
    private var totalPayable: Double { emi * Double(months) }
    private var totalInterest: Double { max(totalPayable - amount, 0) }
    private var interestPct: Double { totalPayable > 0 ? totalInterest / totalPayable * 100 : 0 }
    private var principalPct: Double { 100 - interestPct }

    private var yearly: [YearBreak] {
        buildYearly(amount: amount, monthlyRate: monthlyRate, emi: emi, years: Int(tenure))
    }
    private var schedule: [SchedRow] {
        buildSchedule(amount: amount, monthlyRate: monthlyRate, emi: emi, months: months)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                hero
                metrics
                parameters
                breakdownHeader
                if tab == .chart { yearlyChart } else { scheduleTable }
                infoStrip
            }
            .padding(16)
        }
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("EMI Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MONTHLY EMI")
                .font(.system(size: 11, weight: .bold)).tracking(1)
                .foregroundStyle(.white.opacity(0.7))
            Text(Money.inr(emi))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("per month for \(Int(tenure)) years")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .customerAccent],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            metric("Total Payable", Fmt.shortRupee(totalPayable), "building.columns", .customerAccent)
            metric("Total Interest", Fmt.shortRupee(totalInterest), "chart.line.downtrend.xyaxis", .dealioOrange)
        }
    }

    private func metric(_ label: String, _ value: String, _ icon: String, _ accent: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(accent.opacity(0.12))
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(accent)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 11)).foregroundStyle(Color.dealioTextSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    // MARK: Inputs

    private var parameters: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Loan parameters")
            slider("Loan amount", Fmt.shortRupee(amount), value: $amount,
                   range: 10_00_000...10_00_00_000, step: 500_000)
            slider("Interest rate (p.a.)", String(format: "%.2f%%", rate), value: $rate,
                   range: 7...15, step: 0.05)
            slider("Loan tenure", "\(Int(tenure)) yr", value: $tenure, range: 5...30, step: 1)

            Text("LOAN COMPOSITION")
                .font(.system(size: 11, weight: .bold)).tracking(1)
                .foregroundStyle(Color.dealioTextSecondary)
                .padding(.top, 4)

            HStack(spacing: 20) {
                ZStack {
                    CompositionDonut(principalPct: principalPct)
                    Text("\(Int(principalPct))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 10) {
                    legendRow(.customerAccent, "Principal", "\(Int(principalPct))%")
                    legendRow(.dealioOrange, "Interest", "\(Int(interestPct))%")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func slider(_ label: String, _ value: String, value binding: Binding<Double>,
                        range: ClosedRange<Double>, step: Double) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dealioTextSecondary)
                Spacer()
                Text(value).font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dealioTextPrimary)
            }
            Slider(value: binding, in: range, step: step)
                .tint(.customerAccent)
        }
    }

    private func legendRow(_ color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 12)).foregroundStyle(Color.dealioTextSecondary)
            Text(value).font(.system(size: 12, weight: .bold)).foregroundStyle(Color.dealioTextPrimary)
        }
    }

    // MARK: Breakdown

    private var breakdownHeader: some View {
        HStack {
            SectionLabel("Repayment breakdown")
            Spacer()
            HStack(spacing: 2) {
                ForEach(BreakdownTab.allCases, id: \.self) { option in
                    let on = tab == option
                    Button { withAnimation(.snappy) { tab = option } } label: {
                        Text(option.rawValue)
                            .font(.caption.weight(on ? .bold : .medium))
                            .foregroundStyle(on ? Color.customerAccent : Color.dealioTextSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(on ? Color(.secondarySystemGroupedBackground) : .clear,
                                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color(hex: 0xEDF1F7), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    private var yearlyChart: some View {
        VStack(spacing: 10) {
            YearlyBars(years: yearly)
            HStack(spacing: 16) {
                Spacer()
                legendDot(.customerAccent, "Principal")
                legendDot(.dealioOrange, "Interest")
                Spacer()
            }
        }
        .padding(16).frame(maxWidth: .infinity).cardSurface()
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(Color.dealioTextSecondary)
        }
    }

    private var scheduleTable: some View {
        VStack(spacing: 0) {
            HStack {
                schedHead("Mo", 0.6)
                schedHead("Principal", 1.3)
                schedHead("Interest", 1.3)
                schedHead("Balance", 1.4)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color(hex: 0xF1F4F8))

            // The full schedule is 360 rows at 30 years, so it scrolls inside its
            // own frame rather than stretching the page past any use.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(schedule) { row in
                        HStack {
                            cell("\(row.month)", 0.6, .dealioTextSecondary)
                            cell(Fmt.shortRupee(row.principal), 1.3, .customerAccent, weight: .medium)
                            cell(Fmt.shortRupee(row.interest), 1.3, .dealioOrange, weight: .medium)
                            cell(Fmt.shortRupee(row.outstanding), 1.4, .dealioTextPrimary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 380)
        }
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private func schedHead(_ text: String, _ weight: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold)).tracking(0.5)
            .foregroundStyle(Color.dealioTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(Double(weight))
    }

    private func cell(_ text: String, _ weight: CGFloat, _ color: Color,
                      weight fontWeight: Font.Weight = .regular) -> some View {
        Text(text)
            .font(.system(size: 12, weight: fontWeight))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(Double(weight))
            .lineLimit(1).minimumScaleFactor(0.7)
    }

    private var infoStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoLine("calendar", .customerAccent,
                     "Loan closes in \(Int(tenure)) years (\(months) EMIs)")
            infoLine("info.circle", .dealioOrange,
                     "Interest is \(Int(interestPct))% of your total outflow")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.customerAccent.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoLine(_ icon: String, _ tint: Color, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(tint)
            Text(text).font(.caption).foregroundStyle(Color.dealioTextSecondary)
            Spacer(minLength: 0)
        }
    }
}

/// The principal/interest split as one ring. A donut rather than two bars
/// because the question is "how much of this is interest", which is a share.
private struct CompositionDonut: View {
    let principalPct: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.dealioOrange, lineWidth: 20)
            Circle()
                .trim(from: 0, to: principalPct / 100)
                .stroke(Color.customerAccent, style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                .rotationEffect(.degrees(-90))
        }
        .padding(10)
    }
}

/// Principal and interest per year, stacked. The shape is the point: interest
/// dominates the early years and principal the late ones, which is the single
/// most surprising thing about a home loan.
private struct YearlyBars: View {
    let years: [YearBreak]

    var body: some View {
        let peak = years.map { $0.principal + $0.interest }.max() ?? 1
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(years) { year in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.dealioOrange)
                        .frame(height: max(120 * (year.interest / peak), 1))
                    Rectangle()
                        .fill(Color.customerAccent)
                        .frame(height: max(120 * (year.principal / peak), 1))
                }
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}
