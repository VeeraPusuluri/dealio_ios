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

/// How the result list is ordered. Sorting is client-side because
/// `/customer/projects` returns the whole published catalogue in one call.
enum ExploreSort: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case priceLow = "Price: low to high"
    case priceHigh = "Price: high to low"
    case name = "Name A–Z"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recommended: return "sparkles"
        case .priceLow: return "arrow.up.right"
        case .priceHigh: return "arrow.down.right"
        case .name: return "textformat.abc"
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
    @Published var sort: ExploreSort = .recommended
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

    /// How many *refinements* are on, for the badge on the filter button. The
    /// city sits in its own visible chip row and the query in the search box, so
    /// neither is hidden behind the sheet and neither is counted here.
    var refinementCount: Int {
        (selectedBHK != nil ? 1 : 0) + (selectedBudget != nil ? 1 : 0) + (sort != .recommended ? 1 : 0)
    }

    func clearFilters() {
        selectedCity = nil; selectedBHK = nil; selectedBudget = nil; query = ""; sort = .recommended
    }

    func clearRefinements() {
        selectedBHK = nil; selectedBudget = nil; sort = .recommended
    }

    /// BHK chip options actually present in the catalogue (4+ collapsed to 4).
    var bhkOptions: [Int] {
        let values = Set(projects.flatMap { $0.configurations ?? [] }.compactMap { bhkValue($0) }.map { min($0, 4) })
        return values.sorted()
    }

    /// Budget buckets that would actually return something, so a buyer never
    /// taps a chip that empties the screen.
    var budgetOptions: [BudgetBucket] {
        BudgetBucket.allCases.filter { bucket in
            projects.contains { project in
                guard let price = project.priceMin ?? project.priceMax, price > 0 else { return false }
                return bucket.contains(price)
            }
        }
    }

    /// Featured projects for the carousel — respects the city filter only.
    var featured: [Project] {
        projects.filter { ($0.featured ?? false) && (selectedCity == nil || $0.city == selectedCity) }
    }

    var showFeatured: Bool {
        !featured.isEmpty && query.isEmpty && selectedBHK == nil && selectedBudget == nil
    }

    var filtered: [Project] {
        let matched = projects.filter { matchesCity($0) && matchesQuery($0) && matchesBHK($0) && matchesBudget($0) }
        return sorted(matched)
    }

    private func sorted(_ list: [Project]) -> [Project] {
        switch sort {
        case .recommended:
            // Featured first, then closing-soon, then the server's own order.
            return list.enumerated().sorted { a, b in
                let rankA = (a.element.featured ?? false ? 0 : 1, a.element.closingSoon ?? false ? 0 : 1, a.offset)
                let rankB = (b.element.featured ?? false ? 0 : 1, b.element.closingSoon ?? false ? 0 : 1, b.offset)
                return rankA < rankB
            }.map(\.element)
        case .priceLow:
            return list.sorted { (price($0) ?? .greatestFiniteMagnitude) < (price($1) ?? .greatestFiniteMagnitude) }
        case .priceHigh:
            return list.sorted { (price($0) ?? 0) > (price($1) ?? 0) }
        case .name:
            return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func price(_ p: Project) -> Double? {
        guard let value = p.priceMin ?? p.priceMax, value > 0 else { return nil }
        return value
    }

    private func matchesCity(_ p: Project) -> Bool { selectedCity == nil || p.city == selectedCity }

    private func matchesQuery(_ p: Project) -> Bool {
        query.isEmpty ||
            p.name.localizedCaseInsensitiveContains(query) ||
            (p.locality ?? "").localizedCaseInsensitiveContains(query) ||
            (p.city ?? "").localizedCaseInsensitiveContains(query) ||
            (p.builderName ?? "").localizedCaseInsensitiveContains(query)
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

// MARK: - Screen

struct ExploreView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = ExploreModel()
    @State private var showFilters = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: router.path(0)) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
                    hero

                    cityChips

                    if model.loading && model.projects.isEmpty {
                        skeletonList
                    } else if let error = model.error, model.projects.isEmpty {
                        errorState(error)
                    } else {
                        if model.showFeatured {
                            featuredSection
                        }

                        resultsHeader

                        if model.filtered.isEmpty {
                            emptyState
                        } else {
                            ForEach(model.filtered) { project in
                                NavigationLink(value: project) {
                                    CustomerProjectCard(project: project)
                                }
                                .buttonStyle(.pressable)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.bottom, 28)
            }
            .dealioPageBackground(.customerSurface)
            .heroScrollEdges()
            .scrollDismissesKeyboard(.immediately)
            .navigationDestination(for: Project.self) { CustomerProjectDetailView(project: $0) }
            .portalDestinations()
            .navigationBarHidden(true)
            .task { await model.load() }
            .refreshable { await model.load() }
            .sheet(isPresented: $showFilters) {
                ExploreFilterSheet(model: model)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi \(auth.user?.fullName?.components(separatedBy: " ").first ?? "there") 👋")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Find your next home")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.customerAccentBright)
                }
                Spacer(minLength: 0)
                NavigationLink(value: PortalRoute.customerNotifications) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.15), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Notifications")
            }

            searchField

            statStrip
        }
        .padding(.horizontal, 20)
        .padding(.top, SafeArea.top + 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandHeaderBackground())
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28,
                                          style: .continuous))
    }

    /// Always-visible search. The old screen hid it behind a magnifier toggle,
    /// which put the primary action of a browse page two taps away.
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.dealioTextSecondary)
            TextField("Search projects, localities, builders…", text: $model.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .submitLabel(.search)
                .foregroundStyle(Color.dealioTextPrimary)
                .tint(.customerAccent)
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.dealioTextSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            Divider().frame(height: 22)
            Button { showFilters = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(model.refinementCount > 0 ? Color.customerAccent
                                         : Color.dealioTextSecondary)
                        .frame(width: 24, height: 24)
                    if model.refinementCount > 0 {
                        Circle()
                            .fill(Color.customerAccent)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filters and sorting")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.dealioSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }

    /// A one-line read on the catalogue, so the header carries information and
    /// not just decoration.
    private var statStrip: some View {
        HStack(spacing: 18) {
            statItem("\(model.projects.count)", "projects")
            Divider().frame(height: 18).overlay(Color.white.opacity(0.25))
            statItem("\(model.cities.count)", model.cities.count == 1 ? "city" : "cities")
            Divider().frame(height: 18).overlay(Color.white.opacity(0.25))
            statItem("\(model.featured.count)", "featured")
            Spacer(minLength: 0)
        }
        .opacity(model.loading && model.projects.isEmpty ? 0.35 : 1)
        .animation(.easeOut(duration: 0.25), value: model.projects.count)
    }

    private func statItem(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: City filter

    private var cityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ExploreChip(label: "All cities", icon: "globe.asia.australia.fill",
                            selected: model.selectedCity == nil) {
                    withAnimation(.snappy) { model.selectedCity = nil }
                }
                ForEach(model.cities, id: \.self) { city in
                    ExploreChip(label: city, icon: "building.2.fill",
                                selected: model.selectedCity == city) {
                        withAnimation(.snappy) {
                            model.selectedCity = model.selectedCity == city ? nil : city
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    // MARK: Featured

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Color.customerAccentBright)
                Text("Featured")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(model.featured) { project in
                        NavigationLink(value: project) {
                            FeaturedProjectCard(project: project)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Results

    private var resultsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.selectedCity.map { "Homes in \($0)" } ?? "All homes")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Spacer()
                Text("\(model.filtered.count) result\(model.filtered.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dealioTextSecondary)
                    .contentTransition(.numericText())
            }

            // Whatever is hidden inside the sheet gets a visible, removable chip
            // here — a filter a person cannot see is a filter they will blame on
            // an empty catalogue.
            if model.refinementCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let bhk = model.selectedBHK {
                            activeFilterChip(bhk >= 4 ? "4+ BHK" : "\(bhk) BHK") {
                                model.selectedBHK = nil
                            }
                        }
                        if let budget = model.selectedBudget {
                            activeFilterChip(budget.label) { model.selectedBudget = nil }
                        }
                        if model.sort != .recommended {
                            activeFilterChip(model.sort.rawValue) { model.sort = .recommended }
                        }
                        Button("Clear all") { withAnimation(.snappy) { model.clearRefinements() } }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.customerAccent)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.snappy, value: model.refinementCount)
    }

    private func activeFilterChip(_ label: String, remove: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { remove() } } label: {
            HStack(spacing: 5) {
                Text(label).font(.caption.weight(.semibold))
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.customerAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.customerAccent.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.customerAccent.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove filter \(label)")
    }

    // MARK: States

    /// Shaped placeholders rather than a lone spinner — the page keeps its
    /// layout while loading, so nothing jumps when the real cards land.
    private var skeletonList: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.dealioFieldFill)
                        .frame(height: 170)
                    RoundedRectangle(cornerRadius: 6).fill(Color.dealioFieldFill).frame(width: 170, height: 15)
                    RoundedRectangle(cornerRadius: 6).fill(Color.dealioFieldFill).frame(width: 110, height: 12)
                }
                .padding(14)
                .cardSurface(cornerRadius: 20)
                .padding(.horizontal, 16)
            }
        }
        .redacted(reason: .placeholder)
        .shimmer()
        .accessibilityHidden(true)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            ErrorBanner(message: message)
            Button {
                Task { await model.load() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.customerAccent, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.title)
                .foregroundStyle(Color.customerAccent)
                .frame(width: 60, height: 60)
                .background(Color.customerAccent.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text("No homes found")
                .font(.headline)
                .foregroundStyle(Color.dealioTextPrimary)
            Text(model.hasActiveFilters
                 ? "Try adjusting or clearing your filters."
                 : "Try a different city or search term.")
                .font(.subheadline)
                .foregroundStyle(Color.dealioTextSecondary)
                .multilineTextAlignment(.center)
            if model.hasActiveFilters {
                Button("Clear all filters") { withAnimation(.snappy) { model.clearFilters() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.customerAccent)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }
}

// MARK: - Filter sheet

/// BHK, budget and sort. These were computed by the model but never rendered,
/// so a buyer could filter by city and nothing else; this is where they live.
private struct ExploreFilterSheet: View {
    @ObservedObject var model: ExploreModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !model.bhkOptions.isEmpty {
                        group("Bedrooms", icon: "bed.double.fill") {
                            FlowLayout(spacing: 8) {
                                ForEach(model.bhkOptions, id: \.self) { bhk in
                                    ExploreChip(label: bhk >= 4 ? "4+ BHK" : "\(bhk) BHK",
                                                icon: nil,
                                                selected: model.selectedBHK == bhk,
                                                accent: .customerAccent) {
                                        withAnimation(.snappy) {
                                            model.selectedBHK = model.selectedBHK == bhk ? nil : bhk
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !model.budgetOptions.isEmpty {
                        group("Budget", icon: "indianrupeesign.circle.fill") {
                            FlowLayout(spacing: 8) {
                                ForEach(model.budgetOptions) { bucket in
                                    ExploreChip(label: bucket.label, icon: nil,
                                                selected: model.selectedBudget == bucket,
                                                accent: .customerAccent) {
                                        withAnimation(.snappy) {
                                            model.selectedBudget = model.selectedBudget == bucket ? nil : bucket
                                        }
                                    }
                                }
                            }
                        }
                    }

                    group("Sort by", icon: "arrow.up.arrow.down") {
                        VStack(spacing: 0) {
                            ForEach(Array(ExploreSort.allCases.enumerated()), id: \.element) { index, option in
                                Button {
                                    withAnimation(.snappy) { model.sort = option }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: option.icon)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(model.sort == option ? Color.customerAccent
                                                             : Color.dealioTextSecondary)
                                            .frame(width: 22)
                                        Text(option.rawValue)
                                            .font(.subheadline.weight(model.sort == option ? .semibold : .regular))
                                            .foregroundStyle(Color.dealioTextPrimary)
                                        Spacer()
                                        if model.sort == option {
                                            Image(systemName: "checkmark")
                                                .font(.footnote.weight(.bold))
                                                .foregroundStyle(Color.customerAccent)
                                        }
                                    }
                                    .padding(.vertical, 13)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if index < ExploreSort.allCases.count - 1 {
                                    Divider().padding(.leading, 34)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .dealioPageBackground(.customerSurface)
            .navigationTitle("Refine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { withAnimation(.snappy) { model.clearRefinements() } }
                        .disabled(model.refinementCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Show \(model.filtered.count)") { dismiss() }
                        .font(.headline)
                }
            }
        }
    }

    private func group<C: View>(_ title: String, icon: String,
                                @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.customerAccent)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dealioSurface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.dealioCardBorder, lineWidth: 0.5))
    }
}

// MARK: - Chip

struct ExploreChip: View {
    let label: String
    let icon: String?
    let selected: Bool
    var accent: Color = .customerAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                }
                Text(label).font(.subheadline.weight(selected ? .semibold : .regular))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? accent : Color.dealioSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Color.dealioCardBorder, lineWidth: 1))
            .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
            .shadow(color: selected ? accent.opacity(0.28) : .black.opacity(0.04), radius: 5, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Cards

/// A full-width browse card for the customer Explore list.
struct CustomerProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                ProjectHeroImage(project: project)
                    .frame(height: 178)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // Scrim so the price sits legibly on any photo.
                LinearGradient(colors: [.clear, .black.opacity(0.62)],
                               startPoint: .center, endPoint: .bottom)
                    .frame(height: 178)
                    .allowsHitTesting(false)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(priceRange)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        if let configs = project.configurations?.filter({ !$0.isEmpty }), !configs.isEmpty {
                            Text(configs.prefix(3).joined(separator: " · "))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    if let available = project.availableUnits, available > 0 {
                        Text("\(available) left")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.22), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(14)

                VStack {
                    HStack(spacing: 6) {
                        if project.featured ?? false {
                            Badge(text: "Featured", systemImage: "star.fill", color: .customerAccent)
                        }
                        if project.closingSoon ?? false {
                            Badge(text: "Closing soon", systemImage: "flame.fill", color: .dealioOrange)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(10)
            }
            .frame(height: 178)
            .clipped()

            VStack(alignment: .leading, spacing: 7) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)

                let location = [project.locality, project.city].compactMap { $0 }.joined(separator: ", ")
                if !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(Color.dealioTextSecondary)
                        .lineLimit(1)
                }

                if !metaChips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(metaChips, id: \.0) { chip in
                            HStack(spacing: 4) {
                                Image(systemName: chip.1).font(.system(size: 9, weight: .semibold))
                                Text(chip.0).font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(Color.dealioTextSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.dealioFieldFill, in: Capsule())
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the project")
    }

    private var priceRange: String { Self.priceRange(project) }

    private var metaChips: [(String, String)] {
        var chips: [(String, String)] = []
        if let status = project.status?.replacingOccurrences(of: "_", with: " ").capitalized,
           !status.isEmpty {
            chips.append((status, "building.2"))
        }
        if let possession = project.possessionDate, !possession.isEmpty {
            chips.append((possession, "calendar"))
        }
        if let rera = project.reraNumber, !rera.isEmpty {
            chips.append(("RERA", "checkmark.seal.fill"))
        }
        return chips
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
        ZStack(alignment: .bottomLeading) {
            ProjectHeroImage(project: project)
                .frame(width: 250, height: 190)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.30), .black.opacity(0.78)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Label(project.city ?? "—", systemImage: "mappin")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                Text(CustomerProjectCard.priceRange(project))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.customerAccentBright)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(width: 250, alignment: .leading)
        }
        .frame(width: 250, height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
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
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
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
                    } else if phase.error != nil {
                        Image(systemName: "building.2").font(.largeTitle).foregroundStyle(.white.opacity(0.5))
                    } else {
                        ProgressView().tint(.white.opacity(0.7))
                    }
                }
            } else {
                Image(systemName: "building.2").font(.largeTitle).foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - Shimmer

/// A slow highlight sweep for redacted placeholders, so a loading screen reads
/// as busy rather than broken. Disabled under Reduce Motion.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.45), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                        .blendMode(.plusLighter)
                    }
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                            phase = 1.2
                        }
                    }
                }
            }
            .clipped()
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
