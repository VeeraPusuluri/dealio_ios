import SwiftUI

struct BuilderProjectFormView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var city = ""
    @State private var locality = ""
    @State private var projectType = "Apartment"
    @State private var status = "Under Construction"
    @State private var totalUnits = ""
    @State private var priceMin = ""
    @State private var priceMax = ""
    @State private var reraNumber = ""
    @State private var possession = ""
    @State private var saving = false
    @State private var error: String?

    private let types = ["Apartment", "Villa", "Plot", "Commercial"]
    private let statuses = ["Pre-Launch", "Under Construction", "Ready to Move", "Completed"]

    var body: some View {
        Form {
            if let error { Section { Text(error).foregroundStyle(.red).font(.footnote) } }
            Section("Project") {
                TextField("Project name *", text: $name)
                TextField("City", text: $city)
                TextField("Locality", text: $locality)
                Picker("Type", selection: $projectType) { ForEach(types, id: \.self) { Text($0) } }
                Picker("Status", selection: $status) { ForEach(statuses, id: \.self) { Text($0) } }
            }
            Section("Pricing & inventory") {
                TextField("Total units", text: $totalUnits).keyboardType(.numberPad)
                TextField("Price min (₹)", text: $priceMin).keyboardType(.numberPad)
                TextField("Price max (₹)", text: $priceMax).keyboardType(.numberPad)
            }
            Section("Compliance") {
                TextField("RERA number", text: $reraNumber)
                TextField("Possession (e.g. Dec 2026)", text: $possession)
            }
            Section {
                Button { Task { await save() } } label: {
                    HStack { if saving { ProgressView() }; Text(saving ? "Creating…" : "Create project").fontWeight(.semibold) }
                        .frame(maxWidth: .infinity)
                }
                .disabled(saving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("New Project").navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        guard let builderId = await auth.resolvedBuilderId() else { error = "Couldn't resolve builder profile."; return }
        saving = true; defer { saving = false }
        let payload = ProjectPayload(
            name: name.trimmingCharacters(in: .whitespaces),
            city: city.isEmpty ? nil : city,
            locality: locality.isEmpty ? nil : locality,
            projectType: projectType,
            status: status,
            totalUnits: Int(totalUnits),
            priceMin: Double(priceMin),
            priceMax: Double(priceMax),
            reraNumber: reraNumber.isEmpty ? nil : reraNumber,
            possessionDate: possession.isEmpty ? nil : possession
        )
        do {
            _ = try await APIClient.shared.post("/builder/\(builderId)/projects", body: payload) as Project
            dismiss()
        } catch {
            self.error = authMessage(error)
        }
    }
}
