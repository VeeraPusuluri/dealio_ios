import SwiftUI

@MainActor
final class ProjectDetailModel: ObservableObject {
    @Published var project: Project
    @Published var documents: [ProjectDocument] = []
    @Published var loading = true

    init(project: Project) { self.project = project }

    func load() async {
        if let full: Project = try? await APIClient.shared.get("/customer/projects/\(project.id)") {
            project = full
        }
        if let bid = project.builderId {
            documents = (try? await APIClient.shared.get("/builder/\(bid)/projects/\(project.id)/documents")) ?? []
        }
        loading = false
    }

    private func isImage(_ d: ProjectDocument) -> Bool {
        let u = (d.url ?? "").lowercased()
        return u.hasSuffix(".jpg") || u.hasSuffix(".jpeg") || u.hasSuffix(".png") || u.hasSuffix(".webp")
    }
    private func isFloorPlan(_ d: ProjectDocument) -> Bool {
        let t = (d.docType ?? "").lowercased()
        return t.contains("floor") || t.contains("plan") || t.contains("layout")
    }

    var galleryURLs: [URL] {
        var urls: [URL] = []
        if let cover = project.imageURL { urls.append(cover) }
        for d in documents where isImage(d) && !isFloorPlan(d) {
            if let u = d.fileURL, !urls.contains(u) { urls.append(u) }
        }
        return urls
    }
    var floorPlans: [ProjectDocument] { documents.filter { isFloorPlan($0) && isImage($0) } }
}

struct CustomerProjectDetailView: View {
    @StateObject private var model: ProjectDetailModel
    @State private var showBooking = false

    init(project: Project) { _model = StateObject(wrappedValue: ProjectDetailModel(project: project)) }

    private var p: Project { model.project }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    gallery
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        priceCard
                        statsGrid
                        if let total = p.totalUnits, total > 0 { availabilityBar }
                        if let desc = p.description, !desc.isEmpty { descriptionSection(desc) }
                        if let configs = p.configurations, !configs.isEmpty { section("Configurations") { configurationsGrid(configs) } }
                        if let amenities = p.amenities, !amenities.isEmpty { section("Amenities") { amenitiesGrid(amenities) } }
                        if !model.floorPlans.isEmpty { section("Floor Plans") { floorPlansRow } }
                        if let nearby = p.nearbyHighlights, !nearby.isEmpty { section("Nearby Highlights") { nearbyList(nearby) } }
                        if let locAdv = p.locationAdvantages, !locAdv.isEmpty { locationAdvantagesSection(locAdv) }
                        section("Home Loan Calculator") { LoanCalculator(price: p.priceMin ?? p.priceMax ?? 50_00_000) }
                        if let specs = p.specifications { specificationsSection(specs) }
                        if let plans = p.paymentPlans, !plans.isEmpty { paymentPlansSection(plans) }
                        builderSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(p.name)
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.load() }

            // Sticky bottom CTA bar
            bottomBar
        }
        .sheet(isPresented: $showBooking) { BookingSheetView(projectName: p.name) }
    }

    // MARK: - Gallery

    private var gallery: some View {
        let urls = model.galleryURLs
        return Group {
            if urls.isEmpty {
                ProjectHeroImage(project: p).frame(height: 260).clipped()
            } else if urls.count == 1 {
                AsyncImage(url: urls[0]) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else { LinearGradient(colors: [.dealioNavyMid, .brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing) }
                }
                .frame(maxWidth: .infinity).frame(height: 280).clipped()
            } else {
                // Peeking horizontal scroll row — the next image peeks in at the edge,
                // mirroring the website's continuous horizontal gallery.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                            AsyncImage(url: url) { phase in
                                if let img = phase.image { img.resizable().scaledToFill() }
                                else { LinearGradient(colors: [.dealioNavyMid, .brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing) }
                            }
                            .frame(height: 260)
                            .containerRelativeFrame(.horizontal) { length, _ in length - 40 }
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 16)
                }
                .frame(height: 260)
                .padding(.top, 8)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let builder = p.builderName {
                Text(builder.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.brandTeal)
                    .kerning(1.2)
            }
            Text(p.name).font(.title2.weight(.bold)).foregroundStyle(.primary)
            let loc = [p.locality, p.city].compactMap { $0 }.joined(separator: ", ")
            if !loc.isEmpty {
                Label(loc, systemImage: "mappin.and.ellipse")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let status = p.status {
                Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColor(status).opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor(status))
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Price card

    private var priceCard: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PRICE RANGE").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text(priceRange).font(.title3.weight(.bold)).foregroundStyle(.brandTeal)
                if let sqft = p.pricePerSqftMin {
                    Text("₹\(Int(sqft).formatted())/sqft onwards")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let rd = p.reraNumber {
                VStack(alignment: .trailing, spacing: 2) {
                    Label("RERA", systemImage: "checkmark.shield.fill")
                        .font(.caption2.weight(.bold)).foregroundStyle(.green)
                    Text(rd).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(16).cardSurface()
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        let items: [(String, String, String)] = [
            p.totalUnits.map { ("square.grid.2x2", "Total Homes", "\($0)") },
            p.towers.map { ("building.2", "Towers", "\($0)") },
            p.floorsPerTower.map { ("stairs", "Floors", "G+\($0)") },
            p.possessionDate.map { ("calendar", "Possession", String($0.prefix(7))) },
            p.configurations.flatMap { !$0.isEmpty ? ("house", "Types", $0.joined(separator: " · ")) : nil },
            p.landArea.map { ("map", "Land Area", $0) },
        ].compactMap { $0 }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items, id: \.1) { icon, label, value in
                HStack(spacing: 10) {
                    Image(systemName: icon).font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .background(.brandTeal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.brandTeal)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(value).font(.subheadline.weight(.semibold))
                        Text(label).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12).cardSurface()
            }
        }
    }

    // MARK: - Availability bar

    private var availabilityBar: some View {
        let total = max(p.totalUnits ?? 1, 1)
        let sold = min(p.soldUnits ?? 0, total)
        let booked = min(p.bookedUnits ?? 0, total - sold)
        let available = p.availableUnits.map { min($0, total - sold - booked) } ?? max(0, total - sold - booked)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AVAILABILITY").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(available) of \(total) available").font(.caption.weight(.semibold))
            }
            GeometryReader { geo in
                HStack(spacing: 3) {
                    if available > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brandTeal)
                            .frame(width: geo.size.width * CGFloat(available) / CGFloat(total))
                    }
                    if booked > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: geo.size.width * CGFloat(booked) / CGFloat(total))
                    }
                    if sold > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(sold) / CGFloat(total))
                    }
                }
                .frame(height: 10)
            }
            .frame(height: 10)

            HStack(spacing: 16) {
                legend(.brandTeal, "Available \(available)")
                if booked > 0 { legend(.orange, "Booked \(booked)") }
                if sold > 0 { legend(.secondary, "Sold \(sold)") }
            }
        }
        .padding(16).cardSurface()
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Description

    private func descriptionSection(_ text: String) -> some View {
        section("About this Project") {
            Text(text).font(.subheadline).foregroundStyle(.secondary).lineSpacing(4)
        }
    }

    // MARK: - Configurations

    private func configurationsGrid(_ configs: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(configs, id: \.self) { cfg in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cfg).font(.subheadline.weight(.semibold))
                        Text(configAreaRange(cfg)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                    } label: {
                        Text("Enquire")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(.brandTeal, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .padding(14)
                .background(Color.brandTeal.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.brandTeal.opacity(0.15)))
            }
        }
    }

    private func configAreaRange(_ cfg: String) -> String {
        if cfg.contains("4") || cfg.contains("5") { return "1,950 – 2,200 sqft" }
        if cfg.contains("3") { return "1,350 – 1,580 sqft" }
        if cfg.contains("2") { return "970 – 1,150 sqft" }
        if cfg.contains("1") { return "550 – 680 sqft" }
        return "380 – 480 sqft"
    }

    // MARK: - Amenities

    private func amenitiesGrid(_ items: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(items, id: \.self) { a in
                HStack(spacing: 8) {
                    Image(systemName: amenityIcon(a))
                        .font(.system(size: 14))
                        .foregroundStyle(.brandTeal)
                        .frame(width: 26)
                    Text(a).font(.caption).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.brandTeal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Floor plans

    private var floorPlansRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(model.floorPlans) { doc in
                    if let url = doc.fileURL {
                        Link(destination: url) {
                            AsyncImage(url: url) { phase in
                                if let img = phase.image { img.resizable().scaledToFill() }
                                else { Color(.tertiarySystemFill) }
                            }
                            .frame(width: 200, height: 150).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                Text(doc.name ?? "Floor plan")
                                    .font(.caption2.weight(.semibold)).foregroundStyle(.white)
                                    .padding(6).background(.black.opacity(0.4), in: Capsule()).padding(8)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Nearby

    private func nearbyList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.self) { n in
                Label(n, systemImage: "location.circle.fill")
                    .font(.subheadline).foregroundStyle(.primary)
                    .padding(.vertical, 10)
                Divider()
            }
        }
        .padding(.horizontal, 14).cardSurface()
    }

    // MARK: - Location advantages

    private func locationAdvantagesSection(_ items: [LocationAdvantage]) -> some View {
        section("Location Advantages") {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, la in
                    HStack(spacing: 12) {
                        Image(systemName: locIcon(la.category ?? ""))
                            .font(.system(size: 16))
                            .foregroundStyle(.brandTeal)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(la.name ?? "").font(.subheadline.weight(.medium))
                            if let cat = la.category { Text(cat).font(.caption2).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let d = la.distanceKm { Text(d + " km").font(.caption.weight(.semibold)) }
                            if let m = la.driveMinutes { Text(m + " min").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                    .padding(.vertical, 10)
                    if idx < items.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 14).cardSurface()
        }
    }

    private func locIcon(_ cat: String) -> String {
        let s = cat.lowercased()
        if s.contains("hospital") || s.contains("health") { return "cross.case.fill" }
        if s.contains("school") || s.contains("education") { return "graduationcap.fill" }
        if s.contains("transit") || s.contains("metro") || s.contains("station") { return "tram.fill" }
        if s.contains("mall") || s.contains("shop") { return "bag.fill" }
        if s.contains("park") { return "leaf.fill" }
        return "mappin.circle.fill"
    }

    // MARK: - Specifications

    private func specificationsSection(_ specs: Specifications) -> some View {
        let rows: [(String, String?)] = [
            ("Structure", specs.structure),
            ("Flooring", specs.flooring),
            ("Doors", specs.doors),
            ("Windows", specs.windows),
            ("Electrical", specs.electrical),
            ("Plumbing", specs.plumbing),
            ("Kitchen", specs.kitchen),
            ("Bathrooms", specs.bathrooms),
            ("Painting", specs.painting),
        ].filter { $0.1 != nil }

        if rows.isEmpty { return AnyView(EmptyView()) }

        return AnyView(section("Construction Specifications") {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack {
                        Text(row.0).font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
                        Text(row.1!).font(.caption.weight(.semibold)).foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 9)
                    if idx < rows.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 14).cardSurface()
        })
    }

    // MARK: - Payment plans

    private func paymentPlansSection(_ plans: [PaymentPlan]) -> some View {
        section("Payment Plans") {
            VStack(spacing: 8) {
                ForEach(Array(plans.enumerated()), id: \.offset) { _, plan in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "creditcard.fill")
                            .foregroundStyle(.brandTeal)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            if let name = plan.name { Text(name).font(.subheadline.weight(.semibold)) }
                            if let desc = plan.description { Text(desc).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.brandTeal.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.brandTeal.opacity(0.12)))
                }
                // Standard plan tags
                FlexibleView(data: ["20:80 Plan", "Construction Linked", "Pre-EMI Plan", "Bank Tie-ups"], spacing: 8, lineSpacing: 8) { tag in
                    Text(tag).font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Builder section

    private var builderSection: some View {
        section("Developer") {
            VStack(spacing: 0) {
                let rows: [(String, String?)] = [
                    ("Builder", p.builderName),
                    ("Established", p.builderYearEstablished.map { String($0) }),
                    ("Delivered Projects", p.builderDeliveredProjects.map { "\($0) projects" }),
                    ("RERA No.", p.reraNumber),
                    ("RERA Expiry", p.reraExpiry.map { String($0.prefix(10)) }),
                    ("Status", p.status?.replacingOccurrences(of: "_", with: " ").capitalized),
                ].filter { $0.1 != nil }

                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack {
                        Text(row.0).font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
                        Text(row.1!).font(.caption.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 9)
                    if idx < rows.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 14).cardSurface()
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
            } label: {
                Text("Apply for Loan")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.brandTeal, lineWidth: 1.5))
                    .foregroundStyle(.brandTeal)
            }
            Button { showBooking = true } label: {
                Text("Book a Visit")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
    }

    private var priceRange: String {
        let lo = p.priceMin, hi = p.priceMax
        if let lo, lo > 0, let hi, hi > 0, hi != lo { return "\(Money.inr(lo)) – \(Money.inr(hi))" }
        if let lo, lo > 0 { return "\(Money.inr(lo))+" }
        return "Price on request"
    }

    private func statusColor(_ s: String) -> Color {
        switch s.uppercased() {
        case "READY_TO_MOVE", "ACTIVE": return .green
        case "CLOSING_SOON": return .orange
        case "PRE_LAUNCH": return .purple
        default: return .brandTeal
        }
    }

    private func amenityIcon(_ a: String) -> String {
        let s = a.lowercased()
        if s.contains("pool") || s.contains("swim") { return "figure.pool.swim" }
        if s.contains("gym") || s.contains("fitness") { return "dumbbell" }
        if s.contains("park") || s.contains("garden") || s.contains("green") || s.contains("lawn") { return "tree" }
        if s.contains("security") || s.contains("cctv") || s.contains("gated") { return "lock.shield" }
        if s.contains("club") { return "building.columns" }
        if s.contains("play") || s.contains("kids") || s.contains("child") { return "figure.play" }
        if s.contains("parking") || s.contains("car") { return "car" }
        if s.contains("power") || s.contains("backup") { return "bolt" }
        if s.contains("lift") || s.contains("elevator") { return "arrow.up.arrow.down" }
        if s.contains("wifi") || s.contains("internet") { return "wifi" }
        if s.contains("tennis") { return "sportscourt" }
        if s.contains("spa") || s.contains("yoga") || s.contains("wellness") { return "sparkles" }
        if s.contains("jogging") || s.contains("track") { return "figure.run" }
        return "checkmark.seal"
    }
}

// MARK: - Booking sheet

private struct BookingSheetView: View {
    let projectName: String
    @Environment(\.dismiss) private var dismiss
    @State private var requested = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48)).foregroundStyle(.brandTeal)
                    Text("Book a Site Visit").font(.title2.weight(.bold))
                    Text(projectName).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                Spacer()
                Button {
                    withAnimation(.snappy) { requested = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                } label: {
                    Label(requested ? "Visit Requested!" : "Request a Site Visit",
                          systemImage: requested ? "checkmark.circle.fill" : "calendar")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(requested ? AnyShapeStyle(Color.green) : AnyShapeStyle(LinearGradient.brand),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
                .disabled(requested).padding(.horizontal)
                if requested {
                    Text("Our team will reach out shortly to confirm your visit.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Spacer()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

// MARK: - Flow-layout chips

private struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlexibleView(data: items, spacing: 8, lineSpacing: 8) { item in
            Text(item).font(.subheadline.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
    }
}

private struct FlexibleView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in self.generate(in: geo) }
            .frame(height: totalHeight)
    }

    private func generate(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > g.size.width { width = 0; height -= d.height + lineSpacing }
                        let result = width
                        if item == Array(data).last { width = 0 } else { width -= d.width + spacing }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == Array(data).last { height = 0 }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async { binding.wrappedValue = geo.frame(in: .local).size.height }
            return .clear
        }
    }
}

// MARK: - Loan calculator

private struct LoanCalculator: View {
    let price: Double
    @State private var amount: Double
    @State private var rate: Double = 8.65
    @State private var tenure: Double = 20
    @State private var downPct: Double = 20

    init(price: Double) {
        self.price = price
        _amount = State(initialValue: max(price * 0.8, 5_00_000))
    }
    private var loanAmt: Double { amount * (1 - downPct / 100) }
    private var downAmt: Double { amount * downPct / 100 }
    private var emi: Double {
        let r = rate / 12 / 100, n = tenure * 12
        return r > 0 ? loanAmt * r * pow(1 + r, n) / (pow(1 + r, n) - 1) : loanAmt / n
    }
    private var totalPayment: Double { emi * tenure * 12 + downAmt }
    private var totalInterest: Double { totalPayment - amount }

    var body: some View {
        VStack(spacing: 16) {
            // EMI result
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ESTIMATED EMI").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    Text("\(Money.inr(emi))/mo").font(.title2.weight(.bold)).foregroundStyle(.brandTeal)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TOTAL INTEREST").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    Text(Money.inr(totalInterest)).font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                }
            }
            .padding(14).background(Color.brandTeal.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

            // Breakdown mini-row
            HStack(spacing: 0) {
                breakdownCell("Down Payment", Money.inr(downAmt), .brandTeal)
                Divider().frame(height: 36)
                breakdownCell("Loan Amount", Money.inr(loanAmt), .primary)
                Divider().frame(height: 36)
                breakdownCell("Total Cost", Money.inr(totalPayment), .orange)
            }
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            // Sliders
            sliderRow("Property Value", Money.inr(amount))
            Slider(value: $amount, in: 5_00_000...max(price * 1.5, 5_00_001), step: 1_00_000).tint(.brandTeal)

            sliderRow("Down Payment", "\(Int(downPct))%")
            Slider(value: $downPct, in: 10...50, step: 5).tint(.brandTeal)

            sliderRow("Interest Rate", String(format: "%.2f%%", rate))
            Slider(value: $rate, in: 7...15, step: 0.05).tint(.brandTeal)

            sliderRow("Tenure", "\(Int(tenure)) yrs")
            Slider(value: $tenure, in: 5...30, step: 1).tint(.brandTeal)
        }
        .padding(16).cardSurface()
    }

    private func breakdownCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
    private func sliderRow(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.caption).foregroundStyle(.secondary); Spacer(); Text(v).font(.caption.weight(.bold)) }
    }
}

