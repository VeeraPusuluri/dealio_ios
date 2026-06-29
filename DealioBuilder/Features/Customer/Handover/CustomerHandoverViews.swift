import SwiftUI

// MARK: - Possession (read-only)

struct CustomerPossessionView: View {
    private let milestones = [
        "Occupancy Certificate (OC) received",
        "Snagging defects cleared",
        "Final payment & dues settled",
        "Registration & sale deed completed",
        "Utility connections activated",
        "Key handover scheduled",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Image(systemName: "house.lodge.fill").font(.largeTitle).foregroundStyle(.white)
                        .frame(width: 56, height: 56).background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("Tracking begins after handover").font(.headline)
                    Text("Your builder sets up the possession checklist once the project is ready. You'll see live progress here.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(20).cardSurface()

                VStack(alignment: .leading, spacing: 0) {
                    Text("Typical handover milestones").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                    ForEach(milestones, id: \.self) { m in
                        HStack(spacing: 12) {
                            Image(systemName: "clock").foregroundStyle(.secondary)
                            Text(m).font(.subheadline)
                            Spacer()
                            Text("Pending").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(Color(.tertiarySystemFill), in: Capsule())
                        }
                        .padding(.vertical, 11)
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
                .padding(16).cardSurface()
            }
            .padding()
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Possession Tracker")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Snagging (interactive, local)

private struct Snag: Identifiable {
    let id = UUID()
    var location: String; var category: String; var priority: String; var description: String; var status: String
}

struct CustomerSnaggingView: View {
    @State private var snags: [Snag] = []
    @State private var showAdd = false
    @State private var location = "Living Room"
    @State private var category = "Plumbing"
    @State private var priority = "Medium"
    @State private var desc = ""

    private let locations = ["Living Room", "Master Bedroom", "Kitchen", "Bathroom", "Balcony", "Other"]
    private let categories = ["Structural", "Plumbing", "Electrical", "Painting", "Flooring", "Other"]
    private let priorities = ["High", "Medium", "Low"]

    private var resolved: Int { snags.filter { $0.status == "Resolved" }.count }
    private var pending: Int { snags.filter { $0.status != "Resolved" }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    stat("Total", snags.count, .primary)
                    stat("Resolved", resolved, .green)
                    stat("Pending", pending, .orange)
                }

                if showAdd {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("New snag item").font(.headline)
                        Picker("Location", selection: $location) { ForEach(locations, id: \.self) { Text($0) } }.pickerStyle(.menu)
                        Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0) } }.pickerStyle(.menu)
                        Picker("Priority", selection: $priority) { ForEach(priorities, id: \.self) { Text($0) } }.pickerStyle(.segmented)
                        TextField("Describe the defect…", text: $desc, axis: .vertical).lineLimit(2...4)
                            .padding(10).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                        Button {
                            guard !desc.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            snags.append(Snag(location: location, category: category, priority: priority, description: desc, status: "Open"))
                            desc = ""; showAdd = false
                        } label: {
                            Text("Submit snag").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Color.green, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                        }
                    }
                    .padding(16).cardSurface()
                }

                if snags.isEmpty {
                    ContentUnavailableView("No snags reported yet", systemImage: "camera",
                        description: Text("After possession, tap Raise to report defects to your builder.")).padding(.top, 20)
                } else {
                    ForEach($snags) { $snag in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                pill(snag.priority, priorityColor(snag.priority))
                                pill(snag.status, statusColor(snag.status))
                                Spacer()
                            }
                            Text(snag.description).font(.subheadline.weight(.medium))
                            Text("\(snag.location) · \(snag.category)").font(.caption).foregroundStyle(.secondary)
                            if snag.status == "Resolved" {
                                Button("Reopen") { snag.status = "Reopened" }.font(.caption.weight(.semibold)).foregroundStyle(.red)
                            }
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                    }
                }
            }
            .padding()
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Snagging Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd.toggle() } label: { Label("Raise", systemImage: "plus") }
            }
        }
    }

    private func stat(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(value)").font(.title3.weight(.bold)).foregroundStyle(tint)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).cardSurface()
    }
    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.bold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 2).background(color.opacity(0.15), in: Capsule())
    }
    private func priorityColor(_ p: String) -> Color { p == "High" ? .red : p == "Medium" ? .orange : .blue }
}
