import SwiftUI

struct CustomerDocumentsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CustomerDealsModel()

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if let error = model.error { ErrorBanner(message: error).padding() }
            else if model.deals.isEmpty {
                ContentUnavailableView("No documents yet", systemImage: "doc.text",
                    description: Text("Agreements, receipts and KYC for your bookings appear here."))
            } else {
                List {
                    Section {
                        ForEach(model.deals) { deal in
                            HStack(spacing: 12) {
                                IconBadge(systemImage: "folder.fill", tint: .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(deal.projectName ?? "Booking").font(.subheadline.weight(.semibold))
                                    Text(deal.builderName ?? "—").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(text: deal.dealStatus ?? "—", color: statusColor(deal.dealStatus))
                            }
                            .padding(.vertical, 4)
                        }
                    } footer: {
                        Text("Booking agreements and payment receipts are shared by your builder within each deal. Use Conversations to request copies.")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(phone: auth.phone) }
    }
}
