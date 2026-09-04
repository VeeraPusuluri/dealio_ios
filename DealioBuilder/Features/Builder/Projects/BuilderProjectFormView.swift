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

    // MARK: Per-field validation
    //
    // The form used to have one `validate()` that returned the first problem as
    // a banner at the very bottom of a nine-section scroll — so a builder read
    // "Pincode must be 6 digits" with no idea which of fifty fields it meant.
    // Each rule now also hangs off the field it judges.

    var nameCheck: FieldValidation { .required(name, "Project name") }

    var unitsLabel: String { projectType == "Plot" ? "Total plots" : "Total units" }

    var totalUnitsCheck: FieldValidation {
        .number(totalUnits, unitsLabel, required: true, min: 1)
    }

    var configurationsCheck: FieldValidation {
        if projectType == "Plot" {
            return effectiveConfigurations.isEmpty
                ? .invalid("Add at least one plot size (in sq yd)") : .valid
        }
        return configurations.isEmpty ? .invalid("Select at least one configuration") : .valid
    }

    var reraCheck: FieldValidation { .required(reraNumber, "RERA number") }
    var addressCheck: FieldValidation { .required(address, "Address") }
    var localityCheck: FieldValidation { .required(locality, "Locality") }
    var cityCheck: FieldValidation { .required(city, "City") }
    var pincodeCheck: FieldValidation { .exactDigits(pincode, 6, "Pincode") }
    var priceFromCheck: FieldValidation { .number(priceFrom, "Starting price", required: true, min: 1) }

    /// The ending price also has to be *above* the starting one — the old form
    /// happily saved a range of ₹90 L to ₹40 L.
    var priceToCheck: FieldValidation {
        let base = FieldValidation.number(priceTo, "Ending price", required: true, min: 1)
        guard base.isValid else { return base }
        if let low = Double(priceFrom), let high = Double(priceTo), high < low {
            return .invalid("Ending price can't be below the starting price")
        }
        return .valid
    }

    var possessionCheck: FieldValidation { .required(possessionDate, "Possession date") }
    var commissionCheck: FieldValidation {
        .number(commissionPercent, "Commission", required: false, min: 0, max: 100)
    }
    var websiteCheck: FieldValidation { .url(builderWebsite) }
    var mapsCheck: FieldValidation { .url(googleMapsLink) }
    var videoCheck: FieldValidation { .url(videoUrl) }
    var tourCheck: FieldValidation { .url(virtualTourUrl) }

    /// Every rule, in the order the sections appear.
    private var allChecks: [FieldValidation] {
        [nameCheck, configurationsCheck, totalUnitsCheck, addressCheck, localityCheck,
         cityCheck, pincodeCheck, priceFromCheck, priceToCheck, commissionCheck,
         possessionCheck, reraCheck, mapsCheck, websiteCheck, videoCheck, tourCheck]
    }

    /// Only the rules that stop a save, for the section ticks and the progress bar.
    private var requiredChecks: [FieldValidation] {
        [nameCheck, configurationsCheck, totalUnitsCheck, addressCheck, localityCheck,
         cityCheck, pincodeCheck, priceFromCheck, priceToCheck, possessionCheck, reraCheck]
    }

    var isComplete: Bool { allChecks.allSatisfy(\.isValid) }

    /// 0–1, for the header's progress rail.
    var completion: Double {
        let checks = requiredChecks
        guard !checks.isEmpty else { return 1 }
        return Double(checks.filter(\.isValid).count) / Double(checks.count)
    }

    var identityComplete: Bool { nameCheck.isValid }
    var configComplete: Bool { configurationsCheck.isValid && totalUnitsCheck.isValid }
    var locationComplete: Bool {
        addressCheck.isValid && localityCheck.isValid && cityCheck.isValid && pincodeCheck.isValid
    }
    var pricingComplete: Bool {
        priceFromCheck.isValid && priceToCheck.isValid && possessionCheck.isValid && reraCheck.isValid
    }

    /// The one thing the server will not fix for us: a project the buyer cannot
    /// price, place or trust is not a listing.
    func validate() -> String? {
        allChecks.compactMap(\.error).first
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
            NotificationCenter.default.post(name: .projectSaved, object: nil)
        } catch { self.error = authMessage(error) }
    }
}

extension Notification.Name {
    /// Posted after a project is created or edited, so any open project list
    /// refreshes. The form is reached by value route and has no caller to call
    /// back to.
    static let projectSaved = Notification.Name("dealio.projectSaved")
}

// MARK: - Screen

/// Creating or editing a project.
///
/// Fifty-odd fields, so the shape of the page matters more than any single
/// control. Three things carry it: a progress rail that says how much of the
/// required set is done, section cards that each tick themselves off, and a save
/// bar that names the one thing still blocking rather than greying out silently.
struct BuilderProjectFormView: View {
    var projectId: Int?
    var onSaved: (() -> Void)?

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BuilderProjectFormModel()
    @State private var coverPick: PhotosPickerItem?
    @State private var highlightDraft = ""
    /// Flipped by the first Save attempt so untouched required fields go red.
    @State private var submitted = false

    private var blocker: String? { submitted ? model.validate() : nil }

    var body: some View {
        Group {
            if model.loading {
                ProgressView("Loading project…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            progressHeader
                            identitySection
                            configurationSection
                            locationSection
                            pricingSection
                            complianceSection
                            amenitiesSection
                            specificationsSection
                            paymentPlansSection
                            advantagesSection
                            developerSection
                            mediaSection
                            visibilitySection

                            if let error = model.error, !submitted {
                                ErrorBanner(message: error)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    DealioSaveBar(
                        title: model.isEditing ? "Save changes" : "Publish project",
                        problem: blocker,
                        loading: model.submitting,
                        ready: model.isComplete
                    ) {
                        submitted = true
                        Task { await model.save() }
                    }
                }
            }
        }
        .dealioPageBackground()
        .navigationTitle(model.isEditing ? "Edit project" : "New project")
        .navigationBarTitleDisplayMode(.inline)
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
                let data = try? await item?.loadTransferable(type: Data.self)
                await MainActor.run {
                    model.coverData = data
                    coverPick = nil
                }
            }
        }
    }

    // MARK: Progress

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isEditing ? "Editing" : "New listing")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dealioTealBright)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Text(model.name.trimmedOrNil ?? "Untitled project")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("\(Int(model.completion * 100))%")
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [.dealioTealBright, .dealioTeal],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * model.completion))
                }
            }
            .frame(height: 6)

            Text(model.completion >= 1
                 ? "Everything required is filled in."
                 : "Required fields left to fill in.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandHeaderBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.snappy, value: model.completion)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Form \(Int(model.completion * 100)) percent complete")
    }

    // MARK: Sections

    private var identitySection: some View {
        DealioFormSection(title: "The project", subtitle: "What it's called and what it is",
                          icon: "building.2.fill", tint: .brandTeal,
                          complete: model.identityComplete) {
            DealioTextField(label: "Project name", text: $model.name,
                            placeholder: "e.g. Prestige Lakeside Habitat",
                            icon: "textformat",
                            validation: model.nameCheck, forceError: submitted,
                            capitalization: .words, required: true)

            DealioTextField(label: "Developer name", text: $model.builderName,
                            placeholder: "e.g. Prestige Group",
                            icon: "person.2.fill",
                            helper: "Shown to buyers in the Developer panel.",
                            capitalization: .words)

            // Full width each: "Under Construction" next to "Apartment" left
            // both truncated to "Under…" / "Apartm…" once the icon and chevron
            // had taken their share.
            DealioPickerField(label: "Type", selection: $model.projectType,
                              options: BuilderProjectFormModel.projectTypes,
                              title: { $0 }, icon: "square.grid.2x2")
            DealioPickerField(label: "Status", selection: $model.status,
                              options: BuilderProjectFormModel.statuses,
                              title: { $0 }, icon: "hammer.fill")

            DealioTextField(label: "Description", text: $model.projectDescription,
                            placeholder: "What makes this project worth a visit…",
                            helper: "The first thing a buyer reads on the detail page.",
                            multiline: true, lineLimit: 3...7)
        }
    }

    private var configurationSection: some View {
        DealioFormSection(title: model.projectType == "Plot" ? "Plot sizes" : "Configurations",
                          subtitle: "Inventory on sale",
                          icon: "square.split.bottomrightquarter.fill", tint: .indigo,
                          complete: model.configComplete) {
            if model.projectType == "Plot" {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($model.plotSizes) { $row in
                        HStack(spacing: 10) {
                            DealioTextField(label: "Size", text: $row.yards,
                                            placeholder: "200",
                                            icon: "ruler",
                                            keyboard: .numberPad,
                                            suffix: "sq yd")
                            if model.plotSizes.count > 1 {
                                Button {
                                    withAnimation(.snappy) {
                                        model.plotSizes.removeAll { $0.id == row.id }
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.dealioError)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 20)
                                .accessibilityLabel("Remove this plot size")
                            }
                        }
                    }
                    addRowButton("Add another size") {
                        model.plotSizes.append(PlotSizeInput())
                    }
                    if submitted, let error = model.configurationsCheck.error {
                        fieldError(error)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Unit types", required: true)
                    MultiSelectChips(options: BuilderProjectFormModel.bhkOptions,
                                     selection: $model.configurations)
                    if submitted, let error = model.configurationsCheck.error {
                        fieldError(error)
                    }
                }
            }

            DealioTextField(label: model.unitsLabel, text: $model.totalUnits,
                            placeholder: "240",
                            icon: "number",
                            validation: model.totalUnitsCheck, forceError: submitted,
                            keyboard: .numberPad, required: true)

            if model.projectType != "Plot" {
                HStack(spacing: 10) {
                    DealioTextField(label: "Towers", text: $model.towers,
                                    placeholder: "4", icon: "building.columns",
                                    keyboard: .numberPad)
                    DealioTextField(label: "Floors per tower", text: $model.floorsPerTower,
                                    placeholder: "18", icon: "square.stack.3d.up",
                                    keyboard: .numberPad)
                }
            }

            DealioTextField(label: "Land area", text: $model.landArea,
                            placeholder: "12 acres", icon: "map")
        }
    }

    private var locationSection: some View {
        DealioFormSection(title: "Where it is", subtitle: "Address and neighbourhood",
                          icon: "mappin.and.ellipse", tint: .orange,
                          complete: model.locationComplete) {
            DealioTextField(label: "Street address", text: $model.address,
                            placeholder: "Survey 42, Financial District",
                            icon: "signpost.right",
                            validation: model.addressCheck, forceError: submitted,
                            capitalization: .words,
                            multiline: true, lineLimit: 1...3, required: true)

            HStack(spacing: 10) {
                DealioTextField(label: "Locality", text: $model.locality,
                                placeholder: "Gachibowli", icon: "location",
                                validation: model.localityCheck, forceError: submitted,
                                capitalization: .words, required: true)
                DealioTextField(label: "City", text: $model.city,
                                placeholder: "Hyderabad", icon: "building.2",
                                validation: model.cityCheck, forceError: submitted,
                                capitalization: .words, required: true)
            }

            HStack(spacing: 10) {
                DealioTextField(label: "Pincode", text: $model.pincode,
                                placeholder: "500032", icon: "mappin.circle",
                                validation: model.pincodeCheck, forceError: submitted,
                                keyboard: .numberPad, required: true)
                DealioTextField(label: "Landmark", text: $model.landmark,
                                placeholder: "Near ORR exit 15", icon: "flag",
                                capitalization: .words)
            }

            DealioTextField(label: "Google Maps link", text: $model.googleMapsLink,
                            placeholder: "https://maps.app.goo.gl/…",
                            icon: "map.fill",
                            validation: model.mapsCheck, forceError: submitted,
                            keyboard: .URL, capitalization: .never, autocorrect: false)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Nearby highlights")
                HStack(spacing: 10) {
                    DealioTextField(label: "", text: $highlightDraft,
                                    placeholder: "e.g. 2 km from ORR",
                                    icon: "sparkle")
                    Button {
                        addHighlight()
                    } label: {
                        Text("Add")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(highlightDraft.trimmedOrNil == nil
                                             ? Color.dealioTextSecondary : .white)
                            .padding(.horizontal, 18)
                            .frame(height: DealioMetrics.fieldHeight)
                            .background(highlightDraft.trimmedOrNil == nil
                                        ? Color.dealioButtonDisabled : Color.brandTeal,
                                        in: RoundedRectangle(cornerRadius: DealioMetrics.fieldRadius,
                                                             style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .disabled(highlightDraft.trimmedOrNil == nil)
                }
                if !model.nearbyHighlights.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(model.nearbyHighlights, id: \.self) { highlight in
                            Button {
                                withAnimation(.snappy) {
                                    model.nearbyHighlights.removeAll { $0 == highlight }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(highlight)
                                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                }
                                .font(.caption)
                                .foregroundStyle(Color.brandTeal)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.brandTeal.opacity(0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(highlight)")
                        }
                    }
                }
            }
        }
    }

    private var pricingSection: some View {
        DealioFormSection(title: "Price", subtitle: "What a buyer will pay",
                          icon: "indianrupeesign.circle.fill", tint: .green,
                          complete: model.pricingComplete) {
            HStack(spacing: 10) {
                DealioTextField(label: "Starting price", text: $model.priceFrom,
                                placeholder: "4500000", icon: "arrow.down.right",
                                helper: priceHelper(model.priceFrom),
                                validation: model.priceFromCheck, forceError: submitted,
                                keyboard: .numberPad, required: true)
                DealioTextField(label: "Ending price", text: $model.priceTo,
                                placeholder: "9500000", icon: "arrow.up.right",
                                helper: priceHelper(model.priceTo),
                                validation: model.priceToCheck, forceError: submitted,
                                keyboard: .numberPad, required: true)
            }

            HStack(spacing: 10) {
                DealioTextField(label: "Per sqft from", text: $model.pricePerSqftFrom,
                                placeholder: "6200", icon: "ruler",
                                keyboard: .numberPad, suffix: "₹")
                DealioTextField(label: "Per sqft to", text: $model.pricePerSqftTo,
                                placeholder: "7800", icon: "ruler",
                                keyboard: .numberPad, suffix: "₹")
            }

            HStack(spacing: 10) {
                DealioTextField(label: "Maintenance", text: $model.maintenance,
                                placeholder: "3.5", icon: "wrench.adjustable",
                                helper: "₹ per sqft, monthly.",
                                keyboard: .decimalPad)
                DealioTextField(label: "Floor rise", text: $model.floorRise,
                                placeholder: "40", icon: "arrow.up.square",
                                helper: "₹ per sqft, per floor.",
                                keyboard: .decimalPad)
            }

            DealioTextField(label: "Channel-partner commission", text: $model.commissionPercent,
                            placeholder: "2.5", icon: "percent",
                            helper: commissionHelper,
                            validation: model.commissionCheck, forceError: submitted,
                            keyboard: .decimalPad, suffix: "%")

            DealioTextField(label: "Extra CP incentive", text: $model.cpIncentive,
                            placeholder: "e.g. ₹50k bonus on the first 10 bookings",
                            icon: "gift")

            DealioTextField(label: "Possession", text: $model.possessionDate,
                            placeholder: "Dec 2027", icon: "calendar",
                            validation: model.possessionCheck, forceError: submitted,
                            capitalization: .words, required: true)
        }
    }

    private var complianceSection: some View {
        DealioFormSection(title: "Compliance", subtitle: "RERA and permits",
                          icon: "checkmark.seal.fill", tint: .blue,
                          complete: model.reraCheck.isValid) {
            DealioTextField(label: "RERA number", text: $model.reraNumber,
                            placeholder: "P02400001234", icon: "number.square",
                            helper: "Shown as the trust marker on the buyer's page.",
                            validation: model.reraCheck, forceError: submitted,
                            capitalization: .characters, autocorrect: false, required: true)

            HStack(spacing: 10) {
                DealioTextField(label: "RERA expiry", text: $model.reraExpiry,
                                placeholder: "2028-12-31", icon: "calendar.badge.clock",
                                autocorrect: false)
                DealioTextField(label: "RERA state", text: $model.reraState,
                                placeholder: "Telangana", icon: "map",
                                capitalization: .words)
            }

            DealioTextField(label: "Building permit number", text: $model.buildingPermitNumber,
                            placeholder: "BP/2024/00421", icon: "doc.text",
                            capitalization: .characters, autocorrect: false)
        }
    }

    private var amenitiesSection: some View {
        DealioFormSection(title: "Amenities", subtitle: "\(model.amenities.count) selected",
                          icon: "sparkles", tint: .purple) {
            MultiSelectChips(options: BuilderProjectFormModel.amenityOptions,
                             selection: $model.amenities)
            DealioTextField(label: "Clubhouse area", text: $model.clubhouseAreaSqft,
                            placeholder: "12000", icon: "building.columns",
                            keyboard: .numberPad, suffix: "sqft")
        }
    }

    private var specificationsSection: some View {
        DealioFormSection(title: "Specifications", subtitle: "Optional — shown as a table",
                          icon: "list.bullet.rectangle.fill", tint: .teal) {
            DealioTextField(label: "Structure", text: $model.specStructure,
                            placeholder: "RCC framed, seismic zone II")
            DealioTextField(label: "Flooring", text: $model.specFlooring,
                            placeholder: "Vitrified tiles in living, wooden in master")
            HStack(spacing: 10) {
                DealioTextField(label: "Doors", text: $model.specDoors, placeholder: "Teak frame")
                DealioTextField(label: "Windows", text: $model.specWindows, placeholder: "UPVC")
            }
            HStack(spacing: 10) {
                DealioTextField(label: "Electrical", text: $model.specElectrical, placeholder: "Concealed copper")
                DealioTextField(label: "Plumbing", text: $model.specPlumbing, placeholder: "CPVC")
            }
            HStack(spacing: 10) {
                DealioTextField(label: "Kitchen", text: $model.specKitchen, placeholder: "Granite counter")
                DealioTextField(label: "Bathrooms", text: $model.specBathrooms, placeholder: "Anti-skid tiles")
            }
            DealioTextField(label: "Painting", text: $model.specPainting,
                            placeholder: "Emulsion inside, textured outside")
        }
    }

    private var paymentPlansSection: some View {
        DealioFormSection(title: "Payment plans", subtitle: "How buyers can stage payment",
                          icon: "creditcard.fill", tint: .pink) {
            ForEach($model.paymentPlans) { $plan in
                VStack(alignment: .leading, spacing: 10) {
                    DealioTextField(label: "Plan name", text: $plan.name,
                                    placeholder: "20:80", icon: "tag")
                    DealioTextField(label: "What it means", text: $plan.detail,
                                    placeholder: "20% on booking, 80% on possession",
                                    multiline: true, lineLimit: 1...3)
                    if model.paymentPlans.count > 1 {
                        removeButton("Remove this plan") {
                            model.paymentPlans.removeAll { $0.id == plan.id }
                        }
                    }
                }
                .padding(12)
                .background(Color.dealioFieldFill,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            addRowButton("Add a plan") { model.paymentPlans.append(PaymentPlanInput()) }
        }
    }

    private var advantagesSection: some View {
        DealioFormSection(title: "What's nearby", subtitle: "Distances buyers ask about",
                          icon: "location.magnifyingglass", tint: .cyan) {
            ForEach($model.locationAdvantages) { $advantage in
                VStack(alignment: .leading, spacing: 10) {
                    DealioPickerField(label: "Category", selection: $advantage.category,
                                      options: BuilderProjectFormModel.advantageCategories,
                                      title: { $0 }, icon: "square.grid.2x2")
                    DealioTextField(label: "Name", text: $advantage.name,
                                    placeholder: "Hitec City", icon: "mappin",
                                    capitalization: .words)
                    HStack(spacing: 10) {
                        DealioTextField(label: "Distance", text: $advantage.distanceKm,
                                        placeholder: "6.5", keyboard: .decimalPad, suffix: "km")
                        DealioTextField(label: "Drive time", text: $advantage.driveMinutes,
                                        placeholder: "15", keyboard: .numberPad, suffix: "min")
                    }
                    if model.locationAdvantages.count > 1 {
                        removeButton("Remove this landmark") {
                            model.locationAdvantages.removeAll { $0.id == advantage.id }
                        }
                    }
                }
                .padding(12)
                .background(Color.dealioFieldFill,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            addRowButton("Add a landmark") { model.locationAdvantages.append(LocationAdvInput()) }
        }
    }

    private var developerSection: some View {
        DealioFormSection(title: "About the developer", subtitle: "Builds buyer trust",
                          icon: "person.2.badge.key.fill", tint: .indigo) {
            DealioTextField(label: "About", text: $model.builderAbout,
                            placeholder: "Three decades of residential development across South India…",
                            multiline: true, lineLimit: 2...6)
            HStack(spacing: 10) {
                DealioTextField(label: "Year established", text: $model.builderYearEstablished,
                                placeholder: "1986", icon: "calendar", keyboard: .numberPad)
                DealioTextField(label: "Projects delivered", text: $model.builderDeliveredProjects,
                                placeholder: "42", icon: "checkmark.seal", keyboard: .numberPad)
            }
            DealioTextField(label: "Website", text: $model.builderWebsite,
                            placeholder: "www.example.com", icon: "safari",
                            validation: model.websiteCheck, forceError: submitted,
                            keyboard: .URL, capitalization: .never, autocorrect: false)
        }
    }

    private var mediaSection: some View {
        DealioFormSection(title: "Media", subtitle: "Cover photo, video and tour",
                          icon: "photo.fill", tint: .brandTeal) {
            coverPreview

            PhotosPicker(selection: $coverPick, matching: .images) {
                Label(hasCover ? "Replace cover photo" : "Add a cover photo",
                      systemImage: hasCover ? "arrow.triangle.2.circlepath" : "photo.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandTeal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandTeal.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.brandTeal.opacity(0.32),
                                      style: StrokeStyle(lineWidth: 1, dash: hasCover ? [] : [5, 4])))
            }

            DealioTextField(label: "Video URL", text: $model.videoUrl,
                            placeholder: "https://youtube.com/watch?v=…", icon: "play.rectangle",
                            validation: model.videoCheck, forceError: submitted,
                            keyboard: .URL, capitalization: .never, autocorrect: false)

            DealioTextField(label: "Virtual tour URL", text: $model.virtualTourUrl,
                            placeholder: "https://my.matterport.com/show/…", icon: "view.3d",
                            validation: model.tourCheck, forceError: submitted,
                            keyboard: .URL, capitalization: .never, autocorrect: false)
        }
    }

    private var visibilitySection: some View {
        DealioFormSection(title: "Visibility", subtitle: "Where this listing surfaces",
                          icon: "eye.fill", tint: .dealioOrange) {
            toggleRow("Feature on the home page",
                      "Puts it in the buyer's Featured carousel.",
                      "star.fill", $model.featured)
            Divider()
            toggleRow("Mark as closing soon",
                      "Adds an urgency badge on the browse card.",
                      "flame.fill", $model.closingSoon)
        }
    }

    // MARK: Small pieces

    private var hasCover: Bool { model.coverData != nil || model.existingImageUrl != nil }

    @ViewBuilder private var coverPreview: some View {
        if let data = model.coverData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(height: 150).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if let existing = AppConfig.resolveAssetURL(model.existingImageUrl) {
            AsyncImage(url: existing) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Rectangle().fill(Color.dealioFieldFill)
                    ProgressView()
                }
            }
            .frame(height: 150).frame(maxWidth: .infinity).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String, _ icon: String,
                           _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(binding.wrappedValue ? Color.dealioOrange : Color.dealioTextSecondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dealioTextPrimary)
                    Text(subtitle).font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                }
            }
        }
        .tint(.brandTeal)
    }

    private func fieldLabel(_ text: String, required: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(text).font(.caption.weight(.semibold)).foregroundStyle(Color.dealioTextSecondary)
            if required {
                Text("*").font(.caption.weight(.semibold)).foregroundStyle(Color.dealioError)
            }
        }
    }

    private func fieldError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.dealioError)
    }

    private func addRowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Label(title, systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandTeal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func removeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Label(title, systemImage: "trash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dealioError)
        }
        .buttonStyle(.plain)
    }

    private func addHighlight() {
        guard let value = highlightDraft.trimmedOrNil else { return }
        if !model.nearbyHighlights.contains(value) {
            withAnimation(.snappy) { model.nearbyHighlights.append(value) }
        }
        highlightDraft = ""
    }

    /// Echoes a rupee figure back in words, so a missing or extra zero in a
    /// nine-digit number is caught while typing rather than after publishing.
    private func priceHelper(_ raw: String) -> String? {
        guard let value = Double(raw.filter { $0.isNumber || $0 == "." }), value > 0 else { return nil }
        return Money.inr(value)
    }

    private var commissionHelper: String {
        guard let percent = Double(model.commissionPercent), percent > 0,
              let price = Double(model.priceFrom), price > 0 else {
            return "What a partner earns per booking."
        }
        return "About \(Money.inr(price * percent / 100)) on a \(Money.inr(price)) booking."
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
