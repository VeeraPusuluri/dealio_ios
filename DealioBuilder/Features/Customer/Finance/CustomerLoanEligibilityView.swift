import SwiftUI

/// How much a buyer can actually borrow, and who will lend it.
///
/// Two ceilings apply and the lower one wins: what the income services, and what
/// the property is worth at 80% LTV. Showing only the first is how a buyer ends
/// up shopping above what any bank will fund. Mirrors Android's
/// `ui/customer/loan/LoanEligibilityScreen.kt`.

private struct BankProduct: Identifiable {
    let name: String
    let rate: Double
    let maxTenure: Int
    let processingFee: Double
    let scheme: String?
    var id: String { name }
}

private let bankProducts = [
    BankProduct(name: "HDFC Bank", rate: 8.50, maxTenure: 30, processingFee: 0.5,
                scheme: "Special NRI rates available"),
    BankProduct(name: "SBI Home Loans", rate: 8.25, maxTenure: 30, processingFee: 0.35,
                scheme: "Women borrowers get 0.05% concession"),
    BankProduct(name: "ICICI Bank", rate: 8.90, maxTenure: 25, processingFee: 0.5, scheme: nil),
    BankProduct(name: "Axis Bank", rate: 8.75, maxTenure: 30, processingFee: 0.5,
                scheme: "Pre-approved for salaried"),
    BankProduct(name: "Kotak Mahindra", rate: 8.65, maxTenure: 25, processingFee: 1.0,
                scheme: "Balance transfer at 8.5%"),
]

struct CustomerLoanEligibilityView: View {
    @State private var income = ""
    @State private var existingEmi = ""
    @State private var propertyValue = ""
    @State private var rate: Double = 8.5
    @State private var tenure: Double = 20
    @State private var digiConnected = false

    /// Banks lend against roughly half of gross income, less whatever is already
    /// committed — the FOIR rule every one of them applies.
    private var netAvailable: Double {
        (Double(income) ?? 0) * 0.5 - (Double(existingEmi) ?? 0)
    }
    private var months: Int { max(Int(tenure * 12), 1) }
    private var monthlyRate: Double { rate / 100 / 12 }

    private var maxLoanByIncome: Double {
        guard netAvailable > 0 else { return 0 }
        let growth = pow(1 + monthlyRate, Double(months))
        return netAvailable * (growth - 1) / (monthlyRate * growth)
    }
    private var maxLoanByLTV: Double { (Double(propertyValue) ?? 0) * 0.8 }
    private var eligibleLoan: Double { min(maxLoanByIncome, maxLoanByLTV) }
    private var estimatedEmi: Double {
        eligibleLoan > 0 ? emiOf(principal: eligibleLoan, annualRate: rate, months: months) : 0
    }

    private var verdict: (fg: Color, bg: Color) {
        if eligibleLoan > 50_00_000 { return (.dealioStatusGreen, .dealioStatusGreenBg) }
        if eligibleLoan > 20_00_000 { return (.dealioStatusAmber, .dealioStatusAmberBg) }
        return (.dealioError, Color(hex: 0xFCEBEB))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                calculator
                digiLocker
                SectionLabel("Compare banks")
                ForEach(bankProducts) { bank in bankCard(bank) }
            }
            .padding(16)
        }
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("Home Loan Eligibility")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Calculator

    private var calculator: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Check eligibility", systemImage: "function")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dealioTextPrimary)
                .padding(.bottom, 4)

            numberField("Gross monthly income (₹)", $income, "e.g. 150000")
            numberField("Existing EMI (₹)", $existingEmi, "0 if none")
            numberField("Property value (₹)", $propertyValue, "e.g. 10000000")

            HStack {
                Text("Interest rate").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dealioTextSecondary)
                Spacer()
                Text(String(format: "%.2f%%", rate))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dealioTextPrimary)
            }
            Slider(value: $rate, in: 6...15, step: 0.05).tint(.customerAccent)

            HStack {
                Text("Tenure").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dealioTextSecondary)
                Spacer()
                Text("\(Int(tenure)) years")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dealioTextPrimary)
            }
            Slider(value: $tenure, in: 5...30, step: 1).tint(.customerAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text("You are eligible for a home loan up to")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text(Money.inr(eligibleLoan))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(verdict.fg)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("Estimated EMI \(Money.inr(estimatedEmi))/month for \(Int(tenure)) yrs at \(String(format: "%.2f", rate))%")
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Which ceiling actually bound the answer, because "why is it
                // this number" is the next question every time.
                if eligibleLoan > 0 {
                    Text(maxLoanByLTV < maxLoanByIncome
                         ? "Capped by the property value — banks fund 80% of it."
                         : "Capped by your income — banks allow about half of it towards EMIs.")
                        .font(.caption2)
                        .foregroundStyle(Color.dealioTextSecondary)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(verdict.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 6)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func numberField(_ label: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(Color.dealioTextSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .onChange(of: text.wrappedValue) { _, new in
                    let digits = new.filter(\.isNumber)
                    if digits != new { text.wrappedValue = digits }
                }
                .padding(12)
                .background(Color.dealioFieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
                )
        }
    }

    // MARK: DigiLocker

    private var digiLocker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fetch documents from DigiLocker")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dealioTextPrimary)

            if digiConnected {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.caption2).foregroundStyle(Color.dealioStatusAmber)
                    Text("Demo mode — production integrates the real DigiLocker API")
                        .font(.caption2).foregroundStyle(Color.dealioStatusAmber)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color.dealioStatusAmberBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.dealioStatusGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Documents connected successfully")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.dealioStatusGreen)
                        Text("Your KYC documents were fetched. An advisor will verify them shortly.")
                            .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.dealioStatusGreenBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                // Nothing is fetched here yet, so there is no "Connecting…"
                // state: a spinner standing in for a call that does not exist
                // only costs the user the wait.
                Button { digiConnected = true } label: {
                    Text("Connect DigiLocker")
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
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    // MARK: Banks

    private func bankCard(_ bank: BankProduct) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.customerAccent.opacity(0.12))
                    Image(systemName: "building.columns")
                        .font(.system(size: 17)).foregroundStyle(Color.customerAccent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(bank.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text("\(bank.maxTenure) yr max · \(Fmt.percent(bank.processingFee)) fee")
                        .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "%.2f%%", bank.rate))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text("p.a.").font(.system(size: 10)).foregroundStyle(Color.dealioTextSecondary)
                }
            }

            if let scheme = bank.scheme {
                Text(scheme).font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }

            Button { rate = bank.rate } label: {
                Text("Use this rate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.customerAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(Color.customerAccent.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }
}
