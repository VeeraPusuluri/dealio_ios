import SwiftUI

// MARK: - Budget buckets

enum BudgetBucket: String, CaseIterable, Identifiable {
    case under50L, l50to1Cr, cr1to2, cr2plus
    var id: String { rawValue }

    var label: String {
        switch self {
        case .under50L: return "< ₹50L"
        case .l50to1Cr: return "₹50L–1Cr"
        case .cr1to2: return "₹1–2Cr"
        case .cr2plus: return "₹2Cr+"
        }
    }

    func contains(_ price: Double) -> Bool {
        switch self {
        case .under50L: return price < 50_00_000
        case .l50to1Cr: return price >= 50_00_000 && price < 1_00_00_000
        case .cr1to2: return price >= 1_00_00_000 && price < 2_00_00_000
        case .cr2plus: return price >= 2_00_00_000
        }
    }
}

/// Leading BHK count parsed from a configuration string like "2 BHK" / "3.5 BHK".
func bhkValue(_ config: String) -> Int? {
    let digits = config.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber }
    return Int(digits)
}

@MainActor
final class ExploreModel: ObservableObject {
    @Published var cities: [String] = []
    @Published var projects: [Project] = []
    @Published var selectedCity: String? = nil
    @Published var selectedBHK: Int? = nil
    @Published var selectedBudget: BudgetBucket? = nil
    @Published var query: String = ""
    @Published var loading = true
    @Published var error: String?

    func load() async {
        loading = projects.isEmpty
        error = nil
        do {
            async let citiesReq: [String] = APIClient.shared.get("/customer/cities")
            async let projectsReq: [Project] = APIClient.shared.get("/customer/projects")
            cities = (try? await citiesReq) ?? []
            projects = try await projectsReq
        } catch {
            self.error = authMessage(error)
        }
        loading = false
    }

    var hasActiveFilters: Bool {
        selectedCity != nil || selectedBHK != nil || selectedBudget != nil || !query.isEmpty
    }

    func clearFilters() {
        selectedCity = nil; selectedBHK = nil; selectedBudget = nil; query = ""
    }

    /// BHK chip options actually present in the catalogue (4+ collapsed to 4).
    var bhkOptions: [Int] {
        let values = Set(projects.flatMap { $0.configurations ?? [] }.compactMap { bhkValue($0) }.map { min($0, 4) })
        return values.sorted()
    }

    /// Featured projects for the carousel — respects the city filter only.
    var featured: [Project] {
        projects.filter { ($0.featured ?? false) && (selectedCity == nil || $0.city == selectedCity) }
    }

    var showFeatured: Bool {
        !featured.isEmpty && query.isEmpty && selectedBHK == nil && selectedBudget == nil
    }

    var filtered: [Project] {
        projects.filter { matchesCity($0) && matchesQuery($0) && matchesBHK($0) && matchesBudget($0) }
    }

    private func matchesCity(_ p: Project) -> Bool { selectedCity == nil || p.city == selectedCity }

    private func matchesQuery(_ p: Project) -> Bool {
        query.isEmpty ||
            p.name.localizedCaseInsensitiveContains(query) ||
            (p.locality ?? "").localizedCaseInsensitiveContains(query) ||
            (p.city ?? "").localizedCaseInsensitiveContains(query)
    }

    private func matchesBHK(_ p: Project) -> Bool {
        guard let target = selectedBHK else { return true }
        let values = (p.configurations ?? []).compactMap { bhkValue($0) }
        return target >= 4 ? values.contains { $0 >= 4 } : values.contains(target)
    }

    private func matchesBudget(_ p: Project) -> Bool {
        guard let bucket = selectedBudget else { return true }
        guard let price = p.priceMin ?? p.priceMax, price > 0 else { return false }
        return bucket.contains(price)
    }
}

struct ExploreView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = ExploreModel()
    @State private var searchExpanded = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    hero(topInset: geo.safeAreaInsets.top)

                    cityChips

                    if model.loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
                    } else if let error = model.error {
                        ErrorBanner(message: error).padding(.horizontal)
                    } else {
                        if model.showFeatured {
                            sectionLabel("Featured")
                            featuredCarousel
                        }

                        HStack {
                            Text(model.selectedCity.map { "Homes in \($0)" } ?? "All homes")
                                .font(.headline)
                            Spacer()
                            if !model.filtered.isEmpty {
                                Text("\(model.filtered.count)")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        if model.filtered.isEmpty {
                            emptyState
                        } else {
                            ForEach(model.filtered) { project in
                                NavigationLink(value: project) {
                                    CustomerProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .ignoresSafeArea(.container, edges: .top)
            }
            .navigationDestination(for: Project.self) { CustomerProjectDetailView(project: $0) }
            .navigationBarHidden(true)
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    // MARK: Hero

    private func hero(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: searchExpanded ? 12 : 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hi \(auth.user?.fullName?.components(separatedBy: " ").first ?? "there") 👋")
                        .font(.title3.weight(.bold)).foregroundStyle(.white)
                    Text("Find your next home")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.dealioTealBright)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        searchExpanded.toggle()
                        if !searchExpanded { model.query = "" }
                    }
                    searchFocused = searchExpanded
                } label: {
                    Image(systemName: searchExpanded ? "xmark" : "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }

            if searchExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search projects, localities…", text: $model.query)
                        .textInputAutocapitalization(.never)
                        .focused($searchFocused)
                        .submitLabel(.search)
                    if !model.query.isEmpty {
                        Button { model.query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, topInset + 10)
        .padding(.bottom, searchExpanded ? 16 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous))
    }

    // MARK: City filter

    private var cityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(label: "All", icon: nil, selected: model.selectedCity == nil) { model.selectedCity = nil }
                ForEach(model.cities, id: \.self) { city in
                    Chip(label: city, icon: "building.2", selected: model.selectedCity == city) { model.selectedCity = city }
                }
            }
            .padding(.horizontal).padding(.vertical, 1)
        }
    }

    private var featuredCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(model.featured) { project in
                    NavigationLink(value: project) {
                        FeaturedProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.headline).padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.title).foregroundStyle(.brandTeal)
                .frame(width: 56, height: 56)
                .background(Color.brandTeal.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("No homes found").font(.headline)
            Text(model.hasActiveFilters ? "Try adjusting or clearing your filters." : "Try a different city or search term.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if model.hasActiveFilters {
                Button("Clear filters") { withAnimation { model.clearFilters() } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.brandTeal).padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }
}

private struct Chip: View {
    let label: String
    let icon: String?
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.caption2)
                }
                Text(label).font(.subheadline.weight(selected ? .semibold : .regular))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? Color.brandTeal : Color.white, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Color.dealioCardBorder, lineWidth: 1))
            .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
            .shadow(color: .black.opacity(selected ? 0.10 : 0), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// A full-width browse card for the customer Explore list.
struct CustomerProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ProjectHeroImage(project: project)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipped()
                if project.featured ?? false {
                    Badge(text: "Featured", systemImage: "star.fill", color: .dealioOrange)
                        .padding(10)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name).font(.headline).lineLimit(1)
                let location = [project.locality, project.city].compactMap { $0 }.joined(separator: ", ")
                if !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(priceRange).font(.subheadline.weight(.bold)).foregroundStyle(.brandTeal)
                if let configs = project.configurations?.filter({ !$0.isEmpty }), !configs.isEmpty {
                    Text(configs.joined(separator: " · "))
                        .font(.caption.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                }
                if !metaLine.isEmpty {
                    Text(metaLine).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(14)
        }
        .cardSurface(cornerRadius: 20)
    }

    private var priceRange: String { Self.priceRange(project) }
    private var metaLine: String {
        var parts: [String] = []
        if let status = project.status, !status.isEmpty { parts.append(status.capitalized) }
        if let possession = project.possessionDate, !possession.isEmpty { parts.append("Possession \(possession)") }
        return parts.joined(separator: " · ")
    }

    static func priceRange(_ project: Project) -> String {
        let lo = project.priceMin, hi = project.priceMax
        if let lo, lo > 0, let hi, hi > 0, hi != lo { return "\(Money.inr(lo)) – \(Money.inr(hi))" }
        if let lo, lo > 0 { return "\(Money.inr(lo))+" }
        return "Price on request"
    }
}

/// Compact card used in the "Featured" horizontal carousel.
struct FeaturedProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectHeroImage(project: project)
                .frame(width: 230, height: 120)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name).font(.subheadline.weight(.bold)).lineLimit(1)
                Text(project.city ?? "—").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(CustomerProjectCard.priceRange(project))
                    .font(.caption.weight(.bold)).foregroundStyle(.brandTeal).lineLimit(1)
            }
            .padding(12)
            .frame(width: 230, alignment: .leading)
        }
        .cardSurface(cornerRadius: 18)
    }
}

/// A small pill badge overlaid on hero imagery.
private struct Badge: View {
    let text: String
    let systemImage: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            Text(text).font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color, in: Capsule())
        .foregroundStyle(.white)
    }
}

/// Shared project hero image with a navy→teal gradient placeholder.
struct ProjectHeroImage: View {
    let project: Project
    var body: some View {
        ZStack {
            LinearGradient(colors: [.dealioNavyMid, .brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let url = project.imageURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "building.2").font(.largeTitle).foregroundStyle(.white.opacity(0.5))
                    }
                }
            } else {
                Image(systemName: "building.2").font(.largeTitle).foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
