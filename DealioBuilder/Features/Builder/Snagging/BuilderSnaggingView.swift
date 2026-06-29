import SwiftUI

struct BuilderSnaggingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    SnagStat(label: "Total", value: "0", tint: .primary)
                    SnagStat(label: "Resolved", value: "0", tint: .green)
                    SnagStat(label: "Pending", value: "0", tint: .orange)
                    SnagStat(label: "Overdue", value: "0", tint: .red)
                }
                ContentUnavailableView("No snags reported yet", systemImage: "wrench.and.screwdriver",
                    description: Text("Defects reported by customers after possession appear here for you to assign, track and resolve."))
                    .padding(.top, 20)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Snagging")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SnagStat: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).cardSurface()
    }
}
