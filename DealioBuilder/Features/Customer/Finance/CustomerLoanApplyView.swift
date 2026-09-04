import SwiftUI

/// The buyer's home-loan application.
///
/// Reached from the deal room once a unit is booked, and from the loans screen.
/// Mirrors Android's `ui/customer/loan/LoanApplyScreen.kt`.
struct CustomerLoanApplyView: View {
    var projectId: Int?
    var builderId: Int?

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var loanAmount = ""
    @State private var propertyValue = ""
    @State private var employment = employmentTypes[0]
    @State private var tenure = 20
    @State private var submitting = false
    @State private var message: String?

    private static let employmentTypes = ["Salaried", "Self-employed", "Business", "Professional"]
    private static let tenureOptions = [10, 15, 20, 25, 30]
    private var employmentTypes: [String] { Self.employmentTypes }

    private var amount: Double { Double(loanAmount) ?? 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tell us a few details and a loan officer will get in touch with the best offers.")
                    .font(.footnote)
                    .foregroundStyle(Color.dealioTextSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Loan amount required")
                    currencyField($loanAmount, placeholder: "50,00,000")
                    if amount > 0 {
                        Text(Money.inr(amount))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.customerAccent)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Property value")
                    currencyField($propertyValue, placeholder: "65,00,000")
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Employment type")
                    WrapPills(options: employmentTypes, selection: employment) { employment = $0 }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Tenure")
                    WrapPills(options: Self.tenureOptions.map { "\($0) yrs" },
                              selection: "\(tenure) yrs") { picked in
                        tenure = Int(picked.replacingOccurrences(of: " yrs", with: "")) ?? tenure
                    }
                }

                Button { Task { await submit() } } label: {
                    Group {
                        if submitting { ProgressView().tint(.white) }
                        else { Text("Submit application").fontWeight(.bold) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(amount > 0 && !submitting ? Color.customerAccent : Color.customerAccent.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(amount <= 0 || submitting)

                if let message {
                    Text(message).font(.footnote).foregroundStyle(Color.dealioTextSecondary)
                }
            }
            .padding(16)
        }
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("Apply for home loan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func currencyField(_ text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 4) {
            Text("₹").foregroundStyle(Color.dealioTextSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .onChange(of: text.wrappedValue) { _, new in
                    let digits = new.filter(\.isNumber)
                    if digits != new { text.wrappedValue = digits }
                }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
        )
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        // A buyer who leaves the property value blank means "the loan is the
        // whole of it" — sending 0 would fail the backend's LTV check.
        let property = Double(propertyValue) ?? amount
        do {
            try await CustomerService.submitLoanApplication(.init(
                builderId: builderId, projectId: projectId,
                customerName: auth.user?.fullName, customerPhone: auth.phone,
                customerEmail: auth.user?.email,
                loanAmount: amount, propertyValue: property,
                employmentType: employment, tenureMonths: tenure * 12
            ))
            message = "Loan application submitted! A loan officer will reach out."
            dismiss()
        } catch { message = authMessage(error) }
    }
}

/// A wrapping row of single-select pills — the pattern every buyer-facing form
/// in the app uses for a short, fixed option list.
struct WrapPills: View {
    let options: [String]
    let selection: String
    var accent: Color = .customerAccent
    let onSelect: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { onSelect(option) } label: {
                    Text(option)
                        .font(.footnote.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(selected ? accent : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? accent : Color.dealioCardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
