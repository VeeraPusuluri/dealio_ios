import SwiftUI
import UIKit

struct CPLoanAssistView: View {
    @Environment(\.openURL) private var openURL
    @State private var lead = ""
    @State private var income = ""
    @State private var propertyValue = ""
    @State private var rate = 8.5
    @State private var tenure = 20.0

    private var eligible: Double {
        let inc = Double(income) ?? 0, prop = Double(propertyValue) ?? 0
        let r = rate / 100 / 12, n = tenure * 12
        let byIncome = inc > 0 ? (inc * 0.5) * (pow(1 + r, n) - 1) / (r * pow(1 + r, n)) : 0
        return min(byIncome, prop * 0.8)
    }
    private var emi: Double {
        guard eligible > 0 else { return 0 }
        let r = rate / 100 / 12, n = tenure * 12
        return eligible * r * pow(1 + r, n) / (pow(1 + r, n) - 1)
    }
    private var tint: Color { eligible > 50_00_000 ? .green : eligible > 20_00_000 ? .orange : .red }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Label("Pre-qualify a lead in seconds and share the estimate on WhatsApp.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    field("Lead name (optional)", "e.g. Ramesh", $lead, .default)
                    field("Gross monthly income (₹)", "e.g. 120000", $income, .numberPad)
                    field("Property value (₹)", "e.g. 9000000", $propertyValue, .numberPad)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text("Interest rate").font(.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2f%%", rate)).font(.caption.weight(.bold)) }
                        Slider(value: $rate, in: 6...15).tint(.brandTeal)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text("Tenure").font(.caption).foregroundStyle(.secondary); Spacer(); Text("\(Int(tenure)) years").font(.caption.weight(.bold)) }
                        Slider(value: $tenure, in: 5...30, step: 1).tint(.brandTeal)
                    }
                }
                .padding(16).cardSurface().padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Indicative eligibility").font(.subheadline.weight(.semibold))
                    Text(Money.inr(eligible)).font(.system(size: 30, weight: .bold)).foregroundStyle(tint)
                    Text("Estimated EMI \(Money.inr(emi))/month for \(Int(tenure)) yrs at \(String(format: "%.2f", rate))%")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

                Button {
                    let who = lead.isEmpty ? "there" : lead
                    let msg = "Hi \(who)! 👋 Based on your details, you're eligible for a home loan up to approximately *\(Money.inr(eligible))*, with an estimated EMI of \(Money.inr(emi))/month over \(Int(tenure)) years at \(String(format: "%.2f", rate))% p.a.\n\nThis is indicative — I can help you get a formal sanction. Shall we proceed?"
                    if let u = Share.whatsAppURL(phone: nil, text: msg) { openURL(u) }
                } label: {
                    Label("Share estimate on WhatsApp", systemImage: "message.fill").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(eligible > 0 ? AnyShapeStyle(Color(red: 0.14, green: 0.83, blue: 0.4)) : AnyShapeStyle(Color.gray.opacity(0.4)), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }.disabled(eligible <= 0).padding(.horizontal)

                Text("Indicative only — actual eligibility depends on the bank's credit assessment.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Loan Assist")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ label: String, _ placeholder: String, _ text: Binding<String>, _ keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text).keyboardType(keyboard)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
