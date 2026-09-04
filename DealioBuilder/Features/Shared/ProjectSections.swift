import SwiftUI

// MARK: - Project page sections shared by every portal
//
// A project is the same project whoever is looking at it. These two blocks used
// to exist only on the buyer/partner page, which meant a builder could fill in
// the developer profile and the surrounding landmarks on the project form and
// then never see either of them back — the one person who could tell they were
// wrong was the one person the app never showed them to.

/// A titled block, matching the rhythm of the other project sections.
private struct ProjectSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.caption).foregroundStyle(.brandTeal)
                }
                Text(title).font(.headline)
            }
            content()
        }
    }
}

// MARK: - Location advantages

/// What's nearby, grouped by the kind of thing it is.
///
/// A flat list of ten landmarks is a list a buyer has to read end-to-end to
/// answer "what are the schools like". Grouping under the category header
/// answers it at a glance, and lets the row itself drop the category caption it
/// was repeating.
struct LocationAdvantagesSection: View {
    let items: [LocationAdvantage]

    var body: some View {
        let groups = Self.grouped(items)
        Group {
            if groups.isEmpty {
                EmptyView()
            } else {
                ProjectSection(title: "Location Advantages", icon: "location.magnifyingglass") {
                    VStack(spacing: 12) {
                        ForEach(groups, id: \.category) { group in
                            self.group(group)
                        }
                    }
                }
            }
        }
    }

    private func group(_ group: AdvantageGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: Self.icon(for: group.category))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(tintGradient(.brandTeal),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(group.category)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Spacer(minLength: 0)
                Text("\(group.items.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.brandTeal)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.brandTeal.opacity(0.12), in: Capsule())
            }
            .padding(.bottom, 10)

            ForEach(Array(group.items.enumerated()), id: \.offset) { index, item in
                row(item)
                if index < group.items.count - 1 {
                    Divider().padding(.leading, 35)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func row(_ item: LocationAdvantage) -> some View {
        let distance = Self.measure(item.distanceKm, unit: "km")
        let drive = Self.measure(item.driveMinutes, unit: "min")

        return HStack(alignment: .center, spacing: 11) {
            Circle()
                .fill(Color.brandTeal.opacity(0.35))
                .frame(width: 6, height: 6)
                .frame(width: 24)

            Text(item.name?.trimmedOrNil ?? "Nearby")
                .font(.subheadline)
                .foregroundStyle(Color.dealioTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            // Distance and drive time as two aligned chips, so the column scans
            // vertically instead of every row wrapping differently.
            HStack(spacing: 6) {
                if let distance { chip(distance, icon: "location.fill") }
                if let drive { chip(drive, icon: "car.fill") }
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func chip(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .semibold))
            Text(text).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(Color.dealioTextSecondary)
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Color.dealioFieldFill, in: Capsule())
    }

    /// One category and the landmarks filed under it.
    fileprivate struct AdvantageGroup {
        let category: String
        let items: [LocationAdvantage]
    }

    /// Groups by category, dropping entries with nothing to name.
    ///
    /// Categories come out in the order the project form offers them, so two
    /// projects list their surroundings in the same order; anything the form
    /// doesn't know about follows, alphabetically, rather than being dropped.
    fileprivate static func grouped(_ items: [LocationAdvantage]) -> [AdvantageGroup] {
        let named = items.filter { $0.name?.trimmedOrNil != nil }
        guard !named.isEmpty else { return [] }

        var buckets: [String: [LocationAdvantage]] = [:]
        for item in named {
            let category = item.category?.trimmedOrNil ?? "Nearby"
            buckets[category, default: []].append(item)
        }

        let preferred = BuilderProjectFormModel.advantageCategories
        let known = preferred.filter { buckets[$0] != nil }
        let extra = buckets.keys.filter { !preferred.contains($0) }.sorted()

        return (known + extra).compactMap { category in
            buckets[category].map { AdvantageGroup(category: category, items: $0) }
        }
    }

    /// Normalises a free-text measurement.
    ///
    /// The form takes these as plain text, so "6.5", "6.5 km" and "~7 km" have
    /// all been entered. Appending the unit unconditionally rendered the second
    /// as "6.5 km km".
    static func measure(_ raw: String?, unit: String) -> String? {
        guard let trimmed = raw?.trimmedOrNil else { return nil }
        let number = trimmed.prefix { $0.isNumber || $0 == "." }
        // No leading number to build on — show whatever the builder wrote.
        guard !number.isEmpty else { return trimmed }
        return "\(number) \(unit)"
    }

    /// The project form's own six categories first, then the free-text spellings
    /// that predate it. Four of the six used to fall through to the generic pin
    /// because only the keywords were matched.
    static func icon(for category: String) -> String {
        let s = category.lowercased()
        if s.contains("corporate") || s.contains("office") || s.contains("tech") {
            return "building.2.fill"
        }
        if s.contains("education") || s.contains("school") || s.contains("college")
            || s.contains("university") { return "graduationcap.fill" }
        if s.contains("healthcare") || s.contains("health") || s.contains("hospital")
            || s.contains("clinic") { return "cross.case.fill" }
        if s.contains("transport") || s.contains("transit") || s.contains("metro")
            || s.contains("station") || s.contains("airport") { return "tram.fill" }
        if s.contains("retail") || s.contains("mall") || s.contains("shop")
            || s.contains("market") { return "bag.fill" }
        if s.contains("leisure") || s.contains("park") || s.contains("garden")
            || s.contains("entertainment") || s.contains("restaurant") { return "leaf.fill" }
        return "mappin.circle.fill"
    }
}

// MARK: - Developer

/// Who is building this, given the weight it deserves.
///
/// It closes the project page, but no longer as the grey six-row key/value table
/// it was — that was the least prominent block on screen, for the single fact a
/// buyer most wants before committing crores. It is now a dark branded panel:
/// the developer's name at headline size, their track record as stat tiles, the
/// RERA registration called out as the trust marker it is, and the website as a
/// live link.
struct DeveloperPanel: View {
    let project: Project

    var body: some View {
        ProjectSection(title: "Developer", icon: "building.columns.fill") {
            VStack(alignment: .leading, spacing: 0) {
                header
                if !stats.isEmpty {
                    Divider().overlay(Color.white.opacity(0.14))
                    statRow
                }
                if let about = project.builderAbout?.trimmedOrNil {
                    Divider().overlay(Color.white.opacity(0.14))
                    Text(about)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.80))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                if project.reraNumber?.trimmedOrNil != nil || project.builderWebsite?.trimmedOrNil != nil {
                    Divider().overlay(Color.white.opacity(0.14))
                    footer
                }
            }
            .background(
                ZStack {
                    LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle()
                        .fill(RadialGradient(colors: [Color.dealioTealBright.opacity(0.26), .clear],
                                             center: .center, startRadius: 0, endRadius: 130))
                        .frame(width: 260, height: 260)
                        .offset(x: 100, y: -80)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.dealioNavyDeep.opacity(0.28), radius: 14, y: 7)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.white.opacity(0.20), lineWidth: 1))
                Image(systemName: "building.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.dealioTealBright)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("Built by")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.dealioTealBright)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(project.builderName?.trimmedOrNil ?? "Developer details on request")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    /// Established / delivered / status — the three numbers that say whether this
    /// developer has done it before.
    private var stats: [(String, String, String)] {
        var stats: [(String, String, String)] = []
        if let year = project.builderYearEstablished, year > 0 {
            stats.append(("\(year)", "Established", "calendar"))
        }
        if let delivered = project.builderDeliveredProjects, delivered > 0 {
            stats.append(("\(delivered)", delivered == 1 ? "Project delivered" : "Projects delivered",
                          "checkmark.seal.fill"))
        }
        if let status = project.status?.replacingOccurrences(of: "_", with: " ").capitalized,
           !status.isEmpty {
            stats.append((status, "This project", "hammer.fill"))
        }
        return stats
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                VStack(spacing: 5) {
                    Image(systemName: stat.2)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dealioTealBright)
                    Text(stat.0)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stat.1)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)

                if index < stats.count - 1 {
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 40)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let rera = project.reraNumber?.trimmedOrNil {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.dealioStatusGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("RERA registered")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(project.reraExpiry.map { "\(rera) · valid to \($0.prefix(10))" } ?? rera)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }

            if let website = project.builderWebsite?.trimmedOrNil,
               let url = URL(string: website.contains("://") ? website : "https://" + website) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari.fill").font(.caption)
                        Text("Visit developer website").font(.caption.weight(.semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color.dealioTealBright)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.10), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
            }
        }
        .padding(16)
    }
}
