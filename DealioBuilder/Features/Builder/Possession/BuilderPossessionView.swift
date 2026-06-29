import SwiftUI

private struct PossessionItem: Identifiable {
    let id = UUID()
    var name: String
    var status: Int // 0 pending, 1 in-progress, 2 done
}

struct BuilderPossessionView: View {
    @State private var items: [PossessionItem] = [
        .init(name: "Occupancy Certificate (OC) received", status: 2),
        .init(name: "Snagging defects cleared", status: 1),
        .init(name: "Final payment & dues settled", status: 0),
        .init(name: "Registration & sale deed completed", status: 0),
        .init(name: "Key handover scheduled", status: 0),
    ]
    @State private var newItem = ""

    private var done: Int { items.filter { $0.status == 2 }.count }
    private var pct: Double { items.isEmpty ? 0 : Double(done) / Double(items.count) }
    private var allDone: Bool { !items.isEmpty && done == items.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Progress
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Handover progress").font(.headline)
                        Spacer()
                        Text("\(Int(pct * 100))%").font(.title3.weight(.bold)).foregroundStyle(allDone ? .green : .brandTeal)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill)).frame(height: 8)
                            Capsule().fill(allDone ? AnyShapeStyle(Color.green) : AnyShapeStyle(LinearGradient.brand))
                                .frame(width: geo.size.width * pct, height: 8)
                        }
                    }
                    .frame(height: 8)
                    Text(allDone ? "All items complete — schedule key handover! 🎉" : "\(items.count - done) remaining · tap an item to advance")
                        .font(.caption).foregroundStyle(allDone ? .green : .secondary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()

                // Checklist
                ForEach($items) { $item in
                    Button {
                        item.status = (item.status + 1) % 3
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(item.status)).foregroundStyle(tint(item.status))
                            Text(item.name)
                                .strikethrough(item.status == 2)
                                .foregroundStyle(item.status == 2 ? .secondary : .primary)
                            Spacer()
                            Text(label(item.status)).font(.caption.weight(.bold)).foregroundStyle(tint(item.status))
                        }
                        .padding(14).frame(maxWidth: .infinity).cardSurface()
                    }
                    .buttonStyle(.plain)
                }

                // Add item
                HStack {
                    TextField("Add checklist item…", text: $newItem)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button {
                        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        items.append(.init(name: trimmed, status: 0)); newItem = ""
                    } label: {
                        Text("Add").font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 11)
                            .background(.brandTeal, in: RoundedRectangle(cornerRadius: 12, style: .continuous)).foregroundStyle(.white)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Possession")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func icon(_ s: Int) -> String { s == 2 ? "checkmark.circle.fill" : s == 1 ? "clock.fill" : "circle" }
    private func tint(_ s: Int) -> Color { s == 2 ? .green : s == 1 ? .orange : .secondary }
    private func label(_ s: Int) -> String { s == 2 ? "Completed" : s == 1 ? "In Progress" : "Pending" }
}
