import SwiftUI

/// Every document a builder has shared with this buyer, flattened out of their
/// deals into one list.
///
/// Grouped by nothing and sorted by nothing in particular: a buyer has a handful
/// of these and is looking for one of them, so the project name on each row is
/// enough to find it. Mirrors Android's `ui/customer/documents/DocumentsScreen.kt`.

struct DocItem: Identifiable {
    let projectName: String
    let document: DealDocument
    var id: Int { document.id }
}

@MainActor
final class CustomerDocumentsModel: ObservableObject {
    @Published var items: [DocItem] = []
    @Published var loading = true
    @Published var error: String?

    func load(phone: String) async {
        loading = items.isEmpty
        error = nil
        do {
            let deals = try await CustomerService.myDeals(phone: phone)
            items = deals.flatMap { deal in
                deal.dealDocuments.map { DocItem(projectName: deal.projectName, document: $0) }
            }
        } catch { self.error = authMessage(error) }
        loading = false
    }
}

struct CustomerDocumentsView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CustomerDocumentsModel()

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.items.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await model.load(phone: auth.phone) } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else if model.items.isEmpty {
                ContentUnavailableView("No documents yet", systemImage: "folder",
                    description: Text("Quotes, agreements and allotment letters shared by builders show up here."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.items) { item in
                            Button {
                                if let url = item.document.fileURL { openURL(url) }
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await model.load(phone: auth.phone) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.customerSurface.ignoresSafeArea())
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(phone: auth.phone) }
    }

    private func row(_ item: DocItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.customerAccent.opacity(0.12))
                Image(systemName: icon(item.document.docType))
                    .foregroundStyle(Color.customerAccent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.document.name.nilIfEmpty ?? item.document.docType.nilIfEmpty ?? "Document")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)
                Text([item.document.docType.nilIfEmpty, item.projectName.nilIfEmpty]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary).lineLimit(1)
                if item.document.createdAt.count >= 10 {
                    Text(String(item.document.createdAt.prefix(10)))
                        .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right.square").foregroundStyle(Color.dealioTextSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
        )
    }

    private func icon(_ docType: String) -> String {
        switch docType.lowercased() {
        case let t where t.contains("agreement") || t.contains("sale deed"): return "signature"
        case let t where t.contains("receipt") || t.contains("payment"): return "indianrupeesign.circle"
        case let t where t.contains("allot"): return "key"
        case let t where t.contains("plan") || t.contains("layout"): return "square.grid.3x3"
        default: return "doc.text"
        }
    }
}
