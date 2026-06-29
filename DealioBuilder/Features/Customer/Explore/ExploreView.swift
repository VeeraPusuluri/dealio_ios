import SwiftUI

@MainActor
final class ExploreModel: ObservableObject {
    @Published var cities: [String] = []
    @Published var projects: [Project] = []
    @Published var selectedCity: String? = nil
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

    var filtered: [Project] {
        projects.filter { p in
            (selectedCity == nil || p.city == selectedCity) &&
            (query.isEmpty ||
                p.name.localizedCaseInsensitiveContains(query) ||
                (p.locality ?? "").localizedCaseInsensitiveContains(query) ||
                (p.city ?? "").localizedCaseInsensitiveContains(query))
        }
    }
}

struct ExploreView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = ExploreModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: []) {
                    hero
                    cityChips
                    if model.loading {
                        ProgressView().padding(.top, 40)
                    } else if let error = model.error {
                        ErrorBanner(message: error).padding(.horizontal)
                    } else if model.filtered.isEmpty {
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
                .padding(.bottom, 24)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationDestination(for: Project.self) { CustomerProjectDetailView(project: $0) }
            .navigationBarHidden(true)
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi \(auth.user?.fullName?.components(separatedBy: " ").first ?? "there") 👋")
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                    Text("Find your next home")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.dealioTealBright)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search projects, localities…", text: $model.query)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(20)
        .padding(.top, 50)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26, style: .continuous))
        .ignoresSafeArea(edges: .top)
    }

    private var cityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(label: "All", selected: model.selectedCity == nil) { model.selectedCity = nil }
                ForEach(model.cities, id: \.self) { city in
                    Chip(label: city, selected: model.selectedCity == city) { model.selectedCity = city }
                }
            }
            .padding(.horizontal)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "building.2").font(.largeTitle).foregroundStyle(.secondary)
            Text("No homes found").font(.headline)
            Text("Try a different city or search term.").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top, 50)
    }
}

private struct Chip: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? Color.brandTeal : Color(.secondarySystemGroupedBackground),
                            in: Capsule())
                .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
        }
        .buttonStyle(.plain)
    }
}

/// A full-width browse card for the customer Explore list.
struct CustomerProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectHeroImage(project: project)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name).font(.headline).lineLimit(1)
                let location = [project.locality, project.city].compactMap { $0 }.joined(separator: ", ")
                if !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(priceRange).font(.subheadline.weight(.bold)).foregroundStyle(.brandTeal)
                if let status = project.status {
                    Text(status.capitalized).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
        .cardSurface(cornerRadius: 20)
    }

    private var priceRange: String {
        let lo = project.priceMin, hi = project.priceMax
        if let lo, lo > 0, let hi, hi > 0, hi != lo { return "\(Money.inr(lo)) – \(Money.inr(hi))" }
        if let lo, lo > 0 { return "\(Money.inr(lo))+" }
        return "Price on request"
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
