import SwiftUI

@MainActor
final class CustomerDealsModel: ObservableObject {
    @Published var deals: [CustomerDeal] = []
    @Published var loading = true
    @Published var error: String?
    func load(phone: String) async {
        loading = deals.isEmpty
        error = nil
        do { deals = try await APIClient.shared.get("/portal/customer/deals?phone=\(phone)") }
        catch { self.error = authMessage(error) }
        loading = false
    }
}

struct CustomerPropertyView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CustomerDealsModel()

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if let error = model.error { ErrorBanner(message: error).padding() }
            else if model.deals.isEmpty {
                ContentUnavailableView("No properties yet", systemImage: "house",
                    description: Text("Homes you book appear here with their status and value."))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(model.deals) { deal in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    IconBadge(systemImage: "house.fill", tint: .brandTeal)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(deal.projectName ?? "Property").font(.subheadline.weight(.bold))
                                        if let builder = deal.builderName { Text(builder).font(.caption).foregroundStyle(.secondary) }
                                    }
                                    Spacer()
                                    StatusBadge(text: deal.dealStatus ?? "—", color: statusColor(deal.dealStatus))
                                }
                                if let v = deal.dealValue, v > 0 {
                                    Text(Money.inr(v)).font(.headline).foregroundStyle(.brandTeal)
                                }
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                        }
                    }.padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("My Properties")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(phone: auth.phone) }
        .refreshable { await model.load(phone: auth.phone) }
    }
}
