import SwiftUI

/// The builder's inventory, project by project — and, on tap, the actual matrix.
///
/// The counts come off the matrix where there is one: the stored
/// `availableUnits` / `bookedUnits` counters are maintained by hand and drift
/// the moment anyone edits units directly, and this screen is where that shows.
/// Mirrors Android's `ui/builder/units/UnitMatrixScreen.kt`.
struct BuilderInventoryView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderProjectsModel()
    @State private var expanded: Int?

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.projects.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else if model.projects.isEmpty {
                ContentUnavailableView("No inventory", systemImage: "square.grid.3x3",
                    description: Text("Create a project to manage its unit inventory."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.projects) { project in
                            InventoryCard(
                                project: project,
                                expanded: expanded == project.id,
                                onToggle: {
                                    withAnimation(.snappy) {
                                        expanded = expanded == project.id ? nil : project.id
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
                .refreshable { await reload() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private func reload() async {
        if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) }
    }
}

private struct InventoryCard: View {
    let project: Project
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        let tally = Units.tally(project)
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text((project.configurations ?? []).joined(separator: ", ").nilIfEmpty ?? "—")
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
            }

            stackedBar(tally)

            HStack {
                legendItem("Total", "\(max(tally.total, 0))", .dealioTextPrimary)
                Spacer()
                legendItem("Available", "\(tally.available)", .dealioTextSecondary)
                Spacer()
                legendItem("Booked", "\(tally.booked)", .dealioStatusAmber)
                Spacer()
                legendItem("Sold", "\(tally.sold)", .dealioStatusGreen)
            }

            Button(action: onToggle) {
                HStack(spacing: 4) {
                    Text(expanded ? "Hide unit matrix" : "Show unit matrix")
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandTeal)
            }
            .buttonStyle(.plain)

            if expanded {
                UnitMatrixGrid(units: Units.of(project))
                NavigationLink { ProjectDetailView(project: project) } label: {
                    Text("Open project to edit")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dealioTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func stackedBar(_ tally: UnitTally) -> some View {
        GeometryReader { geo in
            let total = max(tally.total, 1)
            let width = geo.size.width
            HStack(spacing: 0) {
                if tally.sold > 0 {
                    Rectangle().fill(Color.dealioStatusGreen)
                        .frame(width: width * CGFloat(tally.sold) / CGFloat(total))
                }
                if tally.booked > 0 {
                    Rectangle().fill(Color.dealioStatusAmber)
                        .frame(width: width * CGFloat(tally.booked) / CGFloat(total))
                }
                if tally.available > 0 {
                    Rectangle().fill(Color.dealioCardBorder)
                        .frame(width: width * CGFloat(tally.available) / CGFloat(total))
                }
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .frame(height: 10)
    }

    private func legendItem(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.dealioTextSecondary)
        }
    }
}
