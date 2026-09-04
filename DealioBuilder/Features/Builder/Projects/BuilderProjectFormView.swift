import SwiftUI
import PhotosUI

/// Creating or editing a project — the app's mirror of the web AddProjectWizard.
///
/// One screen for both, so the two cannot drift apart: an id means edit. Every
/// field the API accepts is here, grouped the way the wizard groups them.
/// Mirrors Android's `ProjectFormScreen.kt` + `ProjectFormViewModel.kt`.

// MARK: - The form's own shapes

/// One plot size on sale. A plotted layout is sold by yardage, not bedroom count,
/// and every layout carves its land differently — so the sizes are typed in
/// rather than picked from a fixed list. They are persisted through the same
/// `configurations` field the BHK chips use, as "200 sq yd" labels.
struct PlotSizeInput: Identifiable, Hashable {
    let id = UUID()
    var yards = ""
}

struct PaymentPlanInput: Identifiable, Hashable {
    let id = UUID()
    var name = ""
    var detail = ""
}

struct LocationAdvInput: Identifiable, Hashable {
    let id = UUID()
    var category = "Corporate"
    var name = ""
    var distanceKm = ""
    var driveMinutes = ""
}

func plotLabel(_ yards: Int) -> String { "\(yards) sq yd" }
func parsePlotYards(_ label: String) -> Int { Int(label.filter(\.isNumber)) ?? 0 }

// MARK: - Model

@MainActor
final class BuilderProjectFormModel: ObservableObject {
    // Identity
    @Published var name = ""
    @Published var builderName = ""
    @Published var projectType = "Apartment"
    @Published var configurations: [String] = ["3BHK"]
    @Published var plotSizes: [PlotSizeInput] = [PlotSizeInput()]
    @Published var totalUnits = ""
    @Published var towers = ""
    @Published var floorsPerTower = ""
    @Published var status = "Under Construction"
    @Published var reraNumber = ""
    @Published var reraExpiry = ""
    @Published var reraState = ""
    @Published var landArea = ""
    @Published var buildingPermitNumber = ""
    @Published var projectDescription = ""

    // Location
    @Published var address = ""
    @Published var city = "Hyderabad"
    @Published var locality = ""
    @Published var pincode = ""
    @Published var landmark = ""
    @Published var googleMapsLink = ""
    @Published var nearbyHighlights: [String] = []

    // Pricing
    @Published var priceFrom = ""
    @Published var priceTo = ""
    @Published var pricePerSqftFrom = ""
    @Published var pricePerSqftTo = ""
    @Published var maintenance = ""
    @Published var floorRise = ""
    @Published var commissionPercent = "2.5"
    @Published var cpIncentive = ""
    @Published var possessionDate = ""
    @Published var closingSoon = false
    @Published var featured = false

    // Amenities & specs
    @Published var amenities: [String] = ["Swimming Pool", "Gym", "Clubhouse"]
    @Published var clubhouseAreaSqft = ""
    @Published var specStructure = ""
    @Published var specFlooring = ""
    @Published var specDoors = ""
    @Published var specWindows = ""
    @Published var specElectrical = ""
    @Published var specPlumbing = ""
    @Published var specKitchen = ""
    @Published var specBathrooms = ""
    @Published var specPainting = ""

    // Plans
    @Published var paymentPlans: [PaymentPlanInput] = [
        PaymentPlanInput(name: "20:80", detail: "20% on booking, 80% on possession")
    ]
    @Published var locationAdvantages: [LocationAdvInput] = [LocationAdvInput()]

    // Developer
    @Published var builderAbout = ""
    @Published var builderYearEstablished = ""
    @Published var builderDeliveredProjects = ""
    @Published var builderWebsite = ""

    // Media
    @Published var videoUrl = ""
    @Published var virtualTourUrl = ""
    @Published var coverData: Data?
    @Published var existingImageUrl: String?

    @Published var loading = false
    @Published var submitting = false
    @Published var error: String?
    @Published var savedProjectId: Int?

    private(set) var editingId: Int?
    private var builderId = 0

    static let projectTypes = ["Apartment", "Villa", "Plot", "Commercial", "Township"]
    static let statuses = ["Pre-Launch", "Launched", "Under Construction", "Ready to Move"]
    static let bhkOptions = ["1BHK", "2BHK", "3BHK", "4BHK", "5BHK", "Studio", "Penthouse", "Duplex"]
    static let amenityOptions = [
        "Swimming Pool", "Gym", "Clubhouse", "Kids Play Area", "Jogging Track", "Landscaped Garden",
        "24x7 Security", "Power Backup", "Covered Parking", "Rainwater Harvesting",
        "Indoor Games", "Amphitheatre", "Yoga Deck", "Sports Court", "Party Hall", "EV Charging",
    ]
    static let advantageCategories = ["Corporate", "Education", "Healthcare", "Transport", "Retail", "Leisure"]

    var isEditing: Bool { editingId != nil }

    /// What actually gets stored. For a plot the sizes are the rows the builder
    /// typed, deduped and labelled; for everything else the BHK chips stand.
    var effectiveConfigurations: [String] {
        guard projectType == "Plot" else { return configurations }
        var seen = Set<Int>()
        return plotSizes.compactMap { row in
            guard let yards = Int(row.yards.filter(\.isNumber)), yards > 0, seen.insert(yards).inserted else { return nil }
            return plotLabel(yards)
        }
    }

    func prepare(builderId: Int, projectId: Int?) async {
        self.builderId = builderId
        guard let projectId, editingId != projectId else { return }
        editingId = projectId
        loading = true
        do {
            let project: Project = try await APIClient.shared.get("/builder/\(builderId)/projects/\(projectId)")
            apply(project)
        } catch { self.error = authMessage(error) }
        loading = false
    }

    private func apply(_ project: Project) {
        let type = (project.projectType ?? "APARTMENT").lowercased()
            .split(separator: "_").map { $0.capitalized }.joined(separator: " ")
        name = project.name
        builderName = project.builderName ?? ""
        projectType = Self.projectTypes.contains(type) ? type : "Apartment"
        configurations = project.configurations ?? []
        // For a plot the saved label ("200 sq yd") *is* the size — read the
        // yardage back out of it, or the rows reload empty and saving again
        // wipes the sizes.
        if projectType == "Plot" {
            let rows = (project.configurations ?? []).compactMap { label -> PlotSizeInput? in
                let yards = parsePlotYards(label)
                return yards > 0 ? PlotSizeInput(yards: "\(yards)") : nil
            }
            plotSizes = rows.isEmpty ? [PlotSizeInput()] : rows
        }
        totalUnits = project.totalUnits.map(String.init) ?? ""
        towers = project.towers.map(String.init) ?? ""
        floorsPerTower = project.floorsPerTower.map(String.init) ?? ""
        status = {
            switch (project.status ?? "").uppercased() {
            case "PRE_LAUNCH": return "Pre-Launch"
            case "LAUNCHED": return "Launched"
            case "READY_TO_MOVE": return "Ready to Move"
            default: return "Under Construction"
            }
        }()
        reraNumber = project.reraNumber ?? ""
        reraExpiry = project.reraExpiry ?? ""
        reraState = project.reraState ?? ""
        landArea = project.landArea ?? ""
        buildingPermitNumber = project.buildingPermitNumber ?? ""
        projectDescription = project.description ?? ""
        address = project.address ?? ""
        city = project.city ?? "Hyderabad"
        locality = project.locality ?? ""
        pincode = project.pincode ?? ""
        landmark = project.landmark ?? ""
        googleMapsLink = project.googleMapsLink ?? ""
        nearbyHighlights = project.nearbyHighlights ?? []
        priceFrom = wholeNumber(project.priceMin)
        priceTo = wholeNumber(project.priceMax)
        pricePerSqftFrom = wholeNumber(project.pricePerSqftFrom ?? project.pricePerSqftMin)
        pricePerSqftTo = wholeNumber(project.pricePerSqftTo ?? project.pricePerSqftMax)
        maintenance = wholeNumber(project.maintenanceCharges)
        floorRise = wholeNumber(project.floorRiseCharges)
        commissionPercent = project.commissionValue.map { "\($0)" } ?? "2.5"
        cpIncentive = project.cpIncentive ?? ""
        possessionDate = project.possessionDate ?? ""
        closingSoon = project.closingSoon ?? false
        featured = project.featured ?? false
        amenities = project.amenities ?? []
        clubhouseAreaSqft = project.clubhouseAreaSqft.map(String.init) ?? ""
        specStructure = project.specifications?.structure ?? ""
        specFlooring = project.specifications?.flooring ?? ""
        specDoors = project.specifications?.doors ?? ""
        specWindows = project.specifications?.windows ?? ""
        specElectrical = project.specifications?.electrical ?? ""
        specPlumbing = project.specifications?.plumbing ?? ""
        specKitchen = project.specifications?.kitchen ?? ""
        specBathrooms = project.specifications?.bathrooms ?? ""
        specPainting = project.specifications?.painting ?? ""
        let plans = (project.paymentPlans ?? []).map {
            PaymentPlanInput(name: $0.name ?? "", detail: $0.description ?? "")
        }
        paymentPlans = plans.isEmpty ? [PaymentPlanInput()] : plans
        let advantages = (project.locationAdvantages ?? []).map {
            LocationAdvInput(category: $0.category ?? "Corporate", name: $0.name ?? "",
                             distanceKm: $0.distanceKm ?? "", driveMinutes: $0.driveMinutes ?? "")
        }
        locationAdvantages = advantages.isEmpty ? [LocationAdvInput()] : advantages
        builderAbout = project.builderAbout ?? ""
        builderYearEstablished = project.builderYearEstablished.map(String.init) ?? ""
        builderDeliveredProjects = project.builderDeliveredProjects.map(String.init) ?? ""
        builderWebsite = project.builderWebsite ?? ""
        videoUrl = project.videoUrl ?? ""
        virtualTourUrl = project.virtualTourUrl ?? ""
        existingImageUrl = project.imageUrl ?? project.coverUrl
    }

    private func wholeNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : "\(value)"
    }

    /// The one thing the server will not fix for us: a project the buyer cannot
    /// price, place or trust is not a listing.
    func validate() -> String? {
        if name.trimmedOrNil == nil { return "Project name is required" }
        if projectType == "Plot", effectiveConfigurations.isEmpty { return "Add at least one plot size (in sq yd)" }
        if projectType != "Plot", configurations.isEmpty { return "Select at least one configuration" }
        if (Int(totalUnits.filter(\.isNumber)) ?? 0) <= 0 {
            return projectType == "Plot" ? "Total plots is required" : "Total units is required"
        }
        if reraNumber.trimmedOrNil == nil { return "RERA number is required" }
        if address.trimmedOrNil == nil { return "Address is required" }
        if locality.trimmedOrNil == nil { return "Locality is required" }
        if pincode.filter(\.isNumber).count != 6 { return "Pincode must be 6 digits" }
        if (Double(priceFrom) ?? 0) <= 0 { return "Starting price is required" }
        if (Double(priceTo) ?? 0) <= 0 { return "Ending price is required" }
        if possessionDate.trimmedOrNil == nil { return "Possession date is required" }
        return nil
    }

    private var payload: ProjectPayload {
        let specValues = [specStructure, specFlooring, specDoors, specWindows, specElectrical,
                          specPlumbing, specKitchen, specBathrooms, specPainting]
        let specs = Specifications(
            structure: specStructure.trimmedOrNil, flooring: specFlooring.trimmedOrNil,
            doors: specDoors.trimmedOrNil, windows: specWindows.trimmedOrNil,
            electrical: specElectrical.trimmedOrNil, plumbing: specPlumbing.trimmedOrNil,
            kitchen: specKitchen.trimmedOrNil, bathrooms: specBathrooms.trimmedOrNil,
            painting: specPainting.trimmedOrNil
        )
        let plans = paymentPlans.filter { $0.name.trimmedOrNil != nil }
            .map { PaymentPlan(name: $0.name, description: $0.detail.trimmedOrNil) }
        let advantages = locationAdvantages.filter { $0.name.trimmedOrNil != nil }
            .map { LocationAdvantage(category: $0.category, name: $0.name,
                                     distanceKm: $0.distanceKm.trimmedOrNil,
                                     driveMinutes: $0.driveMinutes.trimmedOrNil) }
        let percent = Double(commissionPercent)
        let configs = effectiveConfigurations
        let rera = reraNumber.trimmedOrNil

        return ProjectPayload(
            name: name.trimmingCharacters(in: .whitespaces),
            city: city.trimmedOrNil,
            locality: locality.trimmedOrNil,
            address: address.trimmedOrNil,
            location: address.trimmedOrNil ?? locality.trimmedOrNil ?? city.trimmedOrNil,
            pincode: pincode.trimmedOrNil,
            landmark: landmark.trimmedOrNil,
            description: projectDescription.trimmedOrNil,
            status: statusEnum(status),
            projectType: projectType.uppercased().replacingOccurrences(of: " ", with: "_"),
            configurations: configs.isEmpty ? nil : configs,
            bhkTypes: configs.isEmpty ? nil : configs,
            amenities: amenities.isEmpty ? nil : amenities,
            nearbyHighlights: nearbyHighlights.isEmpty ? nil : nearbyHighlights,
            totalUnits: Int(totalUnits.filter(\.isNumber)),
            towers: Int(towers.filter(\.isNumber)),
            floorsPerTower: Int(floorsPerTower.filter(\.isNumber)),
            reraNumber: rera, reraId: rera,
            reraExpiry: reraExpiry.trimmedOrNil, reraState: reraState.trimmedOrNil,
            priceMin: Double(priceFrom), priceMax: Double(priceTo),
            pricePerSqftMin: Double(pricePerSqftFrom), pricePerSqftMax: Double(pricePerSqftTo),
            maintenanceCharges: Double(maintenance), floorRiseCharges: Double(floorRise),
            commissionStructure: "FLAT", commissionValue: percent, commissionPercent: percent,
            cpIncentive: cpIncentive.trimmedOrNil,
            possessionDate: possessionDate.trimmedOrNil,
            featured: featured, closingSoon: closingSoon,
            videoUrl: videoUrl.trimmedOrNil, virtualTourUrl: virtualTourUrl.trimmedOrNil,
            googleMapsLink: googleMapsLink.trimmedOrNil,
            landArea: landArea.trimmedOrNil,
            buildingPermitNumber: buildingPermitNumber.trimmedOrNil,
            clubhouseAreaSqft: Int(clubhouseAreaSqft.filter(\.isNumber)),
            specifications: specValues.contains(where: { $0.trimmedOrNil != nil }) ? specs : nil,
            paymentPlans: plans.isEmpty ? nil : plans,
            locationAdvantages: advantages.isEmpty ? nil : advantages,
            builderName: builderName.trimmedOrNil,
            builderAbout: builderAbout.trimmedOrNil,
            builderYearEstablished: Int(builderYearEstablished.filter(\.isNumber)),
            builderDeliveredProjects: Int(builderDeliveredProjects.filter(\.isNumber)),
            builderWebsite: builderWebsite.trimmedOrNil
        )
    }

    private func statusEnum(_ label: String) -> String {
        switch label {
        case "Pre-Launch": return "PRE_LAUNCH"
        case "Launched": return "LAUNCHED"
        case "Under Construction": return "UNDER_CONSTRUCTION"
        case "Ready to Move": return "READY_TO_MOVE"
        default: return "PRE_LAUNCH"
        }
    }

    func save() async {
        if let problem = validate() { error = problem; return }
        submitting = true
        error = nil
        defer { submitting = false }
        do {
            let projectId: Int
            if let editingId {
                try await APIClient.shared.patchVoid("/builder/\(builderId)/projects/\(editingId)", body: payload)
                projectId = editingId
            } else {
                let created: Project = try await APIClient.shared.post("/builder/\(builderId)/projects", body: payload)
                projectId = created.id
            }
            // The cover is a second request: the project has to exist before an
            // upload can be attached to it.
            if let coverData {
                let _: ProjectDocument? = try? await APIClient.shared.upload(
                    "/builder/\(builderId)/projects/\(projectId)/image",
                    fileData: coverData, fileName: "cover.jpg", mimeType: "image/jpeg"
                )
            }
            savedProjectId = projectId
        } catch { self.error = authMessage(error) }
    }
}

// MARK: - Screen

struct BuilderProjectFormView: View {
    var projectId: Int?
    var onSaved: (() -> Void)?

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BuilderProjectFormModel()
    @State private var coverPick: PhotosPickerItem?
    @State private var highlightDraft = ""

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    identitySection
                    configurationSection
                    locationSection
                    pricingSection
                    amenitiesSection
                    specificationsSection
                    plansSection
                    developerSection
                    mediaSection
                    if let error = model.error {
                        Section { ErrorBanner(message: error) }
                    }
                }
            }
        }
        .navigationTitle(model.isEditing ? "Edit project" : "New project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(model.submitting ? "Saving…" : "Save") { Task { await model.save() } }
                    .disabled(model.submitting)
            }
        }
        .task {
            if let id = await auth.resolvedBuilderId() {
                await model.prepare(builderId: id, projectId: projectId)
            }
        }
        .onChange(of: model.savedProjectId) { _, saved in
            if saved != nil { onSaved?(); dismiss() }
        }
        .onChange(of: coverPick) { _, item in
            Task {
                model.coverData = try? await item?.loadTransferable(type: Data.self)
                coverPick = nil
            }
        }
    }

    // MARK: Sections

    private var identitySection: some View {
        Section("The project") {
            TextField("Project name", text: $model.name)
            TextField("Developer name", text: $model.builderName)
            Picker("Type", selection: $model.projectType) {
                ForEach(BuilderProjectFormModel.projectTypes, id: \.self) { Text($0) }
            }
            Picker("Status", selection: $model.status) {
                ForEach(BuilderProjectFormModel.statuses, id: \.self) { Text($0) }
            }
            TextField("Description", text: $model.projectDescription, axis: .vertical).lineLimit(2...6)
        }
    }

    private var configurationSection: some View {
        Section(model.projectType == "Plot" ? "Plot sizes" : "Configurations") {
            if model.projectType == "Plot" {
                ForEach($model.plotSizes) { $row in
                    HStack {
                        TextField("Size in sq yd", text: $row.yards).keyboardType(.numberPad)
                        if model.plotSizes.count > 1 {
                            Button(role: .destructive) {
                                model.plotSizes.removeAll { $0.id == row.id }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).foregroundStyle(Color.dealioError)
                        }
                    }
                }
                Button("Add another size") { model.plotSizes.append(PlotSizeInput()) }
                    .font(.footnote.weight(.semibold))
            } else {
                MultiSelectChips(options: BuilderProjectFormModel.bhkOptions,
                                 selection: $model.configurations)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            TextField(model.projectType == "Plot" ? "Total plots" : "Total units",
                      text: $model.totalUnits).keyboardType(.numberPad)
            if model.projectType != "Plot" {
                TextField("Towers", text: $model.towers).keyboardType(.numberPad)
                TextField("Floors per tower", text: $model.floorsPerTower).keyboardType(.numberPad)
            }
            TextField("Land area (e.g. 12 acres)", text: $model.landArea)
        }
    }

    private var locationSection: some View {
        Section("Where it is") {
            TextField("Street address", text: $model.address, axis: .vertical).lineLimit(1...3)
            TextField("Locality", text: $model.locality)
            TextField("City", text: $model.city)
            TextField("Pincode", text: $model.pincode).keyboardType(.numberPad)
            TextField("Landmark", text: $model.landmark)
            TextField("Google Maps link", text: $model.googleMapsLink)
                .keyboardType(.URL).textInputAutocapitalization(.never)

            VStack(alignment: .leading, spacing: 8) {
                Text("Nearby highlights").font(.caption).foregroundStyle(Color.dealioTextSecondary)
                HStack {
                    TextField("e.g. 2 km from ORR", text: $highlightDraft)
                    Button("Add") {
                        if let value = highlightDraft.trimmedOrNil, !model.nearbyHighlights.contains(value) {
                            model.nearbyHighlights.append(value)
                        }
                        highlightDraft = ""
                    }
                    .disabled(highlightDraft.trimmedOrNil == nil)
                }
                if !model.nearbyHighlights.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(model.nearbyHighlights, id: \.self) { highlight in
                            Button { model.nearbyHighlights.removeAll { $0 == highlight } } label: {
                                HStack(spacing: 4) {
                                    Text(highlight)
                                    Image(systemName: "xmark").font(.system(size: 8))
                                }
                                .font(.caption)
                                .foregroundStyle(Color.brandTeal)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Color.brandTeal.opacity(0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var pricingSection: some View {
        Section("Price and compliance") {
            TextField("Starting price (₹)", text: $model.priceFrom).keyboardType(.numberPad)
            TextField("Ending price (₹)", text: $model.priceTo).keyboardType(.numberPad)
            TextField("Price per sqft from", text: $model.pricePerSqftFrom).keyboardType(.numberPad)
            TextField("Price per sqft to", text: $model.pricePerSqftTo).keyboardType(.numberPad)
            TextField("Maintenance (₹/sqft/month)", text: $model.maintenance).keyboardType(.numberPad)
            TextField("Floor rise (₹/sqft/floor)", text: $model.floorRise).keyboardType(.numberPad)
            TextField("Channel-partner commission %", text: $model.commissionPercent)
                .keyboardType(.decimalPad)
            TextField("Extra CP incentive", text: $model.cpIncentive)
            TextField("Possession (e.g. Dec 2027)", text: $model.possessionDate)
            TextField("RERA number", text: $model.reraNumber).textInputAutocapitalization(.characters)
            TextField("RERA expiry", text: $model.reraExpiry)
            TextField("RERA state", text: $model.reraState)
            TextField("Building permit number", text: $model.buildingPermitNumber)
            Toggle("Feature on the home page", isOn: $model.featured)
            Toggle("Mark as closing soon", isOn: $model.closingSoon)
        }
    }

    private var amenitiesSection: some View {
        Section("Amenities") {
            MultiSelectChips(options: BuilderProjectFormModel.amenityOptions, selection: $model.amenities)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            TextField("Clubhouse area (sqft)", text: $model.clubhouseAreaSqft).keyboardType(.numberPad)
        }
    }

    private var specificationsSection: some View {
        Section("Specifications") {
            TextField("Structure", text: $model.specStructure)
            TextField("Flooring", text: $model.specFlooring)
            TextField("Doors", text: $model.specDoors)
            TextField("Windows", text: $model.specWindows)
            TextField("Electrical", text: $model.specElectrical)
            TextField("Plumbing", text: $model.specPlumbing)
            TextField("Kitchen", text: $model.specKitchen)
            TextField("Bathrooms", text: $model.specBathrooms)
            TextField("Painting", text: $model.specPainting)
        }
    }

    private var plansSection: some View {
        Group {
            Section("Payment plans") {
                ForEach($model.paymentPlans) { $plan in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Name — e.g. 20:80", text: $plan.name)
                        TextField("What it means", text: $plan.detail, axis: .vertical).lineLimit(1...3)
                        if model.paymentPlans.count > 1 {
                            Button("Remove", role: .destructive) {
                                model.paymentPlans.removeAll { $0.id == plan.id }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Button("Add a plan") { model.paymentPlans.append(PaymentPlanInput()) }
                    .font(.footnote.weight(.semibold))
            }

            Section("What's nearby") {
                ForEach($model.locationAdvantages) { $advantage in
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Category", selection: $advantage.category) {
                            ForEach(BuilderProjectFormModel.advantageCategories, id: \.self) { Text($0) }
                        }
                        TextField("Name — e.g. Hitec City", text: $advantage.name)
                        HStack {
                            TextField("km away", text: $advantage.distanceKm).keyboardType(.decimalPad)
                            TextField("min drive", text: $advantage.driveMinutes).keyboardType(.numberPad)
                        }
                        if model.locationAdvantages.count > 1 {
                            Button("Remove", role: .destructive) {
                                model.locationAdvantages.removeAll { $0.id == advantage.id }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Button("Add a landmark") { model.locationAdvantages.append(LocationAdvInput()) }
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private var developerSection: some View {
        Section("About the developer") {
            TextField("About", text: $model.builderAbout, axis: .vertical).lineLimit(2...5)
            TextField("Year established", text: $model.builderYearEstablished).keyboardType(.numberPad)
            TextField("Projects delivered", text: $model.builderDeliveredProjects).keyboardType(.numberPad)
            TextField("Website", text: $model.builderWebsite)
                .keyboardType(.URL).textInputAutocapitalization(.never)
        }
    }

    private var mediaSection: some View {
        Section("Media") {
            if let data = model.coverData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(height: 140).clipped().clipShape(RoundedCornerShape12())
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } else if let existing = AppConfig.resolveAssetURL(model.existingImageUrl) {
                AsyncImage(url: existing) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.dealioFieldFill)
                }
                .frame(height: 140).clipped().clipShape(RoundedCornerShape12())
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            PhotosPicker(selection: $coverPick, matching: .images) {
                Label(model.coverData == nil && model.existingImageUrl == nil ? "Add a cover photo"
                                                                              : "Replace cover photo",
                      systemImage: "photo")
            }
            TextField("Video URL", text: $model.videoUrl)
                .keyboardType(.URL).textInputAutocapitalization(.never)
            TextField("Virtual tour URL", text: $model.virtualTourUrl)
                .keyboardType(.URL).textInputAutocapitalization(.never)
        }
    }
}

/// A wrapping set of multi-select chips — the pattern the wizard uses for BHK
/// types and amenities, where several answers are normal.
struct MultiSelectChips: View {
    let options: [String]
    @Binding var selection: [String]
    var accent: Color = .brandTeal

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let on = selection.contains(option)
                Button {
                    if on { selection.removeAll { $0 == option } } else { selection.append(option) }
                } label: {
                    Text(option)
                        .font(.caption.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? .white : Color.dealioTextSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(on ? accent : Color(.secondarySystemGroupedBackground), in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? accent : Color.dealioCardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
