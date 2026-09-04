import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var router: PortalRouter
    let project: Project


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cover

                VStack(alignment: .leading, spacing: 10) {
                    Text(project.name).font(.title2.bold())
                    if let location = [project.locality, project.city].compactMap({ $0 }).joined(separator: ", ").nilIfEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        if let status = project.status {
                            StatusBadge(text: status, color: statusColor(status))
                        }
                        if let type = project.projectType {
                            StatusBadge(text: type)
                        }
                    }
                }

                priceCard

                SectionHeader(title: "Inventory")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    InfoTile(label: "Total Units", value: intText(project.totalUnits), systemImage: "square.grid.2x2.fill", tint: .brandTeal)
                    InfoTile(label: "Available", value: intText(project.availableUnits), systemImage: "checkmark.circle.fill", tint: .green)
                    InfoTile(label: "Booked", value: intText(project.bookedUnits), systemImage: "bookmark.fill", tint: .orange)
                    InfoTile(label: "Sold", value: intText(project.soldUnits), systemImage: "seal.fill", tint: .purple)
                    InfoTile(label: "RERA", value: project.reraNumber ?? "—", systemImage: "checkmark.shield.fill", tint: .blue)
                    InfoTile(label: "Possession", value: project.possessionDate ?? "—", systemImage: "calendar", tint: .pink)
                }

                // The same two blocks the buyer and the partner see. The builder
                // types both into the project form and, until now, had nowhere to
                // read them back — so a wrong distance or a stale developer bio
                // was only ever visible to the people it was wrong for.
                if let advantages = project.locationAdvantages, !advantages.isEmpty {
                    LocationAdvantagesSection(items: advantages)
                }
                DeveloperPanel(project: project)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { projectActions }
    }

    @ViewBuilder private var cover: some View {
        AsyncImage(url: project.imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    tintGradient(.brandTeal).opacity(0.18)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.brandTeal)
                }
            }
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private var priceCard: some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: "indianrupeesign.circle.fill", tint: .green, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Price Range")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(priceText)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
        }
        .padding(16)
        .cardSurface()
    }

    /// The three things a builder does to a project once it exists. They sit in
    /// the toolbar rather than the page so they stay reachable from any scroll
    /// position.
    private var projectActions: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Edit project", systemImage: "pencil") {
                    router.open(.builderProjectForm(project.id))
                }
                Button("Documents", systemImage: "folder") {
                    router.open(.builderProjectDocuments(project.id))
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var priceText: String {
        switch (project.priceMin, project.priceMax) {
        case let (min?, max?): return "\(Money.inr(min)) – \(Money.inr(max))"
        case let (min?, nil): return Money.inr(min)
        case let (nil, max?): return Money.inr(max)
        default: return "On request"
        }
    }

    private func intText(_ value: Int?) -> String {
        value.map(String.init) ?? "—"
    }
}

struct InfoTile: View {
    let label: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = .brandTeal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardSurface(cornerRadius: 14)
    }
}
