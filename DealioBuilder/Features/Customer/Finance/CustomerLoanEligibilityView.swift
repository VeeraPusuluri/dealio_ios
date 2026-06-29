import SwiftUI

private struct Bank: Identifiable {
    let name: String; let rate: Double; let maxTenure: Int; let fee: Double; let scheme: String?
    var id: String { name }
}
private let banks = [
    Bank(name: "HDFC Bank", rate: 8.50, maxTenure: 30, fee: 0.5, scheme: "Special NRI rates available"),
    Bank(name: "SBI Home Loans", rate: 8.25, maxTenure: 30, fee: 0.35, scheme: "Women borrowers get 0.05% concession"),
    Bank(name: "ICICI Bank", rate: 8.90, maxTenure: 25, fee: 0.5, scheme: nil),
    Bank(name: "Axis Bank", rate: 8.75, maxTenure: 30, fee: 0.5, scheme: "Pre-approved for salaried"),
    Bank(name: "Kotak Mahindra", rate: 8.65, maxTenure: 25, fee: 1.0, scheme: "Balance transfer at 8.5%"),
]

struct CustomerLoanEligibilityView: View {
    @State private var income = ""
    @State private var existingEmi = ""
    @State private var propertyValue = ""
    @State private var rate: Double = 8.5
    @State private var tenure: Double = 20
    @State private var digiState = 0 // 0 idle, 1 connecting, 2 done

    private var eligible: Double {
        let inc = Double(income) ?? 0, emiOut = Double(existingEmi) ?? 0, prop = Double(propertyValue) ?? 0
        let net = inc * 0.5 - emiOut
        let r = rate / 100 / 12, n = tenure * 12
        let byIncome = net > 0 ? net * (pow(1 + r, n) - 1) / (r * pow(1 + r, n)) : 0
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
                VStack(alignment: .leading, spacing: 12) {
                    Label("Check eligibility", systemImage: "function").font(.headline)
                    field("Gross monthly income (₹)", "e.g. 150000", $income)
                    field("Existing EMI (₹)", "0 if none", $existingEmi)
                    field("Property value (₹)", "e.g. 10000000", $propertyValue)
                    HStack { Text("Interest rate").font(.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2f%%", rate)).font(.caption.weight(.bold)) }
                    Slider(value: $rate, in: 6...15, step: 0.05).tint(.brandTeal)
                    HStack { Text("Tenure").font(.caption).foregroundStyle(.secondary); Spacer(); Text("\(Int(tenure)) years").font(.caption.weight(.bold)) }
                    Slider(value: $tenure, in: 5...30, step: 1).tint(.brandTeal)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("You are eligible for a home loan up to").font(.subheadline.weight(.semibold))
                        Text(Money.inr(eligible)).font(.system(size: 26, weight: .bold)).foregroundStyle(tint)
                        Text("Estimated EMI \(Money.inr(emi))/month for \(Int(tenure)) yrs at \(String(format: "%.2f", rate))%")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(16).cardSurface()

                // DigiLocker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fetch documents from DigiLocker").font(.headline)
                    if digiState == 2 {
                        Label("Demo mode — production integrates the real DigiLocker API", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.orange)
                        Label("Documents connected — an advisor will verify your KYC shortly.", systemImage: "checkmark.seal.fill")
                            .font(.subheadline).foregroundStyle(.green)
                    } else {
                        Button {
                            digiState = 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { digiState = 2 }
                        } label: {
                            Text(digiState == 1 ? "Connecting…" : "Connect DigiLocker").font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                        }.disabled(digiState == 1)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()

                // Banks
                Text("Compare banks").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(banks) { bank in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            IconBadge(systemImage: "building.columns", tint: .brandTeal)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(bank.name).font(.subheadline.weight(.semibold))
                                Text("\(bank.maxTenure) yr max · \(bank.fee, specifier: "%.2g")% fee").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(bank.rate, specifier: "%.2f")%").font(.headline)
                                Text("p.a.").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        if let scheme = bank.scheme { Text(scheme).font(.caption).foregroundStyle(.secondary) }
                        Button { rate = bank.rate } label: {
                            Text("Use this rate").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(Color.brandTeal.opacity(0.12), in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.brandTeal)
                        }
                    }
                    .padding(14).cardSurface()
                }
            }
            .padding()
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Home Loan Eligibility")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ label: String, _ placeholder: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text).keyboardType(.numberPad)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
