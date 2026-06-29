import SwiftUI

struct CustomerTopupView: View {
    @State private var outstanding = ""
    @State private var propertyValue = ""
    @State private var yearsPaid = ""
    @State private var income = ""
    @State private var checked = false
    @State private var amount: Double = 20_00_000
    @State private var purpose = "Home Renovation"
    @State private var submitted = false

    private let purposes = ["Home Renovation", "Education", "Medical", "Personal", "Business", "Investment"]
    private let topupRate = 9.25, topupTenure = 19.0

    private var maxTopup: Double { max((Double(propertyValue) ?? 0) * 0.8 - (Double(outstanding) ?? 0), 0) }
    private var eligible: Bool { maxTopup > 0 && (Double(yearsPaid) ?? 0) >= 1 }
    private var emi: Double {
        let r = topupRate / 1200, n = topupTenure * 12
        return amount > 0 ? amount * r / (1 - pow(1 + r, -n)) : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Label("Borrow additional funds against your existing home loan at 8.5–9.5% — no new property paperwork.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Check your eligibility").font(.headline)
                    field("Current loan outstanding (₹)", $outstanding)
                    field("Current property value (₹)", $propertyValue)
                    field("Years of EMI paid on time", $yearsPaid)
                    field("Monthly income (₹)", $income)
                    Button { checked = true; if eligible { amount = min(maxTopup, 20_00_000) } } label: {
                        Text("Check my eligibility").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                    }
                }
                .padding(16).cardSurface()

                if checked {
                    if eligible {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("You're eligible!", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(.green)
                            Text("Maximum top-up: \(Money.inr(maxTopup))").font(.subheadline.weight(.semibold))
                            HStack(spacing: 8) {
                                mini("Rate", String(format: "%.2g%%", topupRate))
                                mini("Tenure", "\(Int(topupTenure)) yr")
                                mini("EMI", Money.inr(emi))
                            }
                            HStack { Text("Amount required").font(.caption).foregroundStyle(.secondary); Spacer(); Text(Money.inr(amount)).font(.caption.weight(.bold)) }
                            Slider(value: $amount, in: 1_00_000...max(maxTopup, 1_00_000)).tint(.brandTeal)
                            Picker("Purpose", selection: $purpose) { ForEach(purposes, id: \.self) { Text($0) } }.pickerStyle(.menu)
                            if submitted {
                                Label("Application submitted! Your bank will contact you within 48 hours.", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline).foregroundStyle(.green)
                            } else {
                                Button { submitted = true } label: {
                                    Text("Apply for top-up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                                        .background(Color.green, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                    } else {
                        Label("Not eligible yet — you need at least 1 year of timely EMI payments and positive equity (property value > 125% of outstanding).", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline).foregroundStyle(.red)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Loan Top-up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", text: text).keyboardType(.numberPad)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    private func mini(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.bold))
        }.frame(maxWidth: .infinity).padding(8).background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
