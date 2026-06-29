import SwiftUI

struct BuilderConversationsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealsModel()

    var body: some View {
        Group {
            if model.loading {
                ProgressView()
            } else if let error = model.error {
                ErrorBanner(message: error).padding()
            } else if model.deals.isEmpty {
                ContentUnavailableView("No conversations yet", systemImage: "bubble.left.and.bubble.right",
                    description: Text("When a customer books a visit, your chat with them appears here."))
            } else {
                List(model.deals) { deal in
                    NavigationLink {
                        BuilderDealDetailView(dealId: deal.id, title: deal.customerName ?? "Conversation")
                    } label: {
                        HStack(spacing: 12) {
                            InitialsAvatar(name: deal.customerName, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deal.customerName ?? "Customer").font(.subheadline.weight(.semibold))
                                Text([deal.projectName, deal.cpName.map { "via \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if let status = deal.status { StatusBadge(text: status, color: statusColor(status)) }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
