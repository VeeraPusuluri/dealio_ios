import SwiftUI

/// Borrowing more against a home loan already running.
///
/// The eligibility is arithmetic the buyer can check themselves — 80% of the
/// property less what is outstanding — so the page shows the working rather than
/// just the verdict. Mirrors Android's `ui/customer/finance/CustomerTopupScreen.kt`.

private let topupRate = 9.25
private let topupTenureYears = 19
private let topupPurposes = ["Home Renovation", "Education", "Medical", "Personal",
                             "Business", "Repay Other Loan", "Investment"]

struct CustomerTopupView: View {
    @State private var outstanding = ""
    @State private var propertyValue = ""
    @State private var yearsPaid = ""
    @State private var income = ""
    @State private var checked = false
    @State private var amount: Double = 20_00_000
    @State private var purpose = topupPurposes[0]
    @State private var submitted = false
    @State private var message: String?

    private var outstandingValue: Double { Double(outstanding) ?? 0 }
    private var propertyValueNumber: Double { Double(propertyValue) ?? 0 }
    private var yearsValue: Double { Double(yearsPaid) ?? 0 }
    private var maxTopup: Double { max(propertyValueNumber * 0.8 - outstandingValue, 0) }
    private var eligible: Bool { maxTopup > 0 && yearsValue >= 1 }
    private var emi: Double {
        emiOf(principal: amount, annualRate: topupRate, months: topupTenureYears * 12)
    }
    private var formComplete: Bool {
        ![outstanding, propertyValue, yearsPaid, income].contains { $0.trimmedOrNil == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                explainer
                checker
                if checked { eligible ? AnyView(result) : AnyView(notEligible) }
                advisor
            }
            .padding(16)
        }
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("Loan Top-up")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Top-up", isPresented: Binding(get: { message != nil },
                                              set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("What is a Top-up Loan?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text("Borrow additional funds against your existing home loan at attractive rates (8.5–9.5%) — for renovation, education, medical or personal needs. No new property paperwork.")
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xEAF0FE), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var checker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Check your eligibility")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dealioTextPrimary)
            numberField("Current loan outstanding (₹)", $outstanding, "e.g. 15800000")
            numberField("Current property value (₹)", $propertyValue, "e.g. 25200000")
            numberField("Years of EMI paid on time", $yearsPaid, "e.g. 2")
            numberField("Monthly income (₹)", $income, "e.g. 180000")

            Button {
                guard formComplete else {
                    message = "Please fill in all fields."
                    return
                }
                checked = true
                if eligible { amount = min(maxTopup, 20_00_000) }
            } label: {
                Text("Check my eligibility")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.customerAccentBright, .customerAccent],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("You're eligible!", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dealioStatusGreen)

            VStack(alignment: .leading, spacing: 1) {
                Text("Maximum top-up: \(Money.inr(maxTopup))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                // The working, not just the answer — a buyer should be able to
                // check the number against their own statement.
                Text("(\(Money.inr(propertyValueNumber)) × 80%) − \(Money.inr(outstandingValue))")
                    .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }

            HStack(spacing: 8) {
                miniInfo("Rate", "\(Fmt.percent(topupRate))")
                miniInfo("Tenure", "\(topupTenureYears) yr")
                miniInfo("EMI", Money.inr(emi))
            }

            HStack {
                Text("Amount required").font(.caption).foregroundStyle(Color.dealioTextSecondary)
                Spacer()
                Text(Money.inr(amount)).font(.footnote.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
            }
            Slider(value: $amount, in: 1_00_000...max(maxTopup, 1_00_000)).tint(.customerAccent)

            Picker("Purpose", selection: $purpose) {
                ForEach(topupPurposes, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.dealioFieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 1) {
                Text("Monthly EMI").font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                Text("\(Money.inr(emi))/month")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text("\(Money.inr(amount)) at \(Fmt.percent(topupRate)) · \(topupTenureYears) yr")
                    .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xF1F4F8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if submitted {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.dealioStatusGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Application submitted!")
                            .font(.footnote.weight(.bold)).foregroundStyle(Color.dealioStatusGreen)
                        Text("Your bank will contact you within 48 hours.")
                            .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.dealioStatusGreenBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Button { submitted = true } label: {
                    Text("Apply for top-up")
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

    private var notEligible: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(Color.dealioError)
            VStack(alignment: .leading, spacing: 2) {
                Text("Not eligible yet")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dealioError)
                Text("You need at least 1 year of timely EMI payments and positive equity (property value must exceed 125% of the outstanding loan).")
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFCEBEB), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var advisor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Have questions about top-up loans?")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dealioTextPrimary)
            Text("Our loan experts can guide you through the process.")
                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            Button { message = "A loan advisor will call you within 24 hours." } label: {
                Text("Talk to an advisor")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.customerAccentBright, .customerAccent],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func miniInfo(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10)).foregroundStyle(Color.dealioStatusGreen)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.dealioTextPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.dealioStatusGreenBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func numberField(_ label: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(Color.dealioTextSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .onChange(of: text.wrappedValue) { _, new in
                    let digits = new.filter(\.isNumber)
                    if digits != new { text.wrappedValue = digits }
                    // Any edit invalidates the verdict below — leaving it up
                    // would show an answer computed from different numbers.
                    checked = false
                    submitted = false
                }
                .padding(12)
                .background(Color.dealioFieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
                )
        }
    }
}
