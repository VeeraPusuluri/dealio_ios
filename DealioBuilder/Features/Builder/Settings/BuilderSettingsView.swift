import SwiftUI

/// The builder's account and company details.
///
/// Signing out must work whether or not the profile call succeeded, so the page
/// always renders: what the server knows is layered on top of the session the
/// app already holds rather than replacing the screen with a full-page error.
/// Mirrors Android's `ui/builder/settings/BuilderSettingsScreen.kt`.

/// The builder's own profile — `builder/:id/profile`.
struct BuilderProfile: Codable {
    var id: Int = 0
    var builderId: Int = 0
    var fullName: String?
    var email: String?
    var phone: String?
    var avatarUrl: String?
    var builder: BuilderInfo?
}

struct BuilderInfo: Codable {
    var companyName: String?
    var about: String?
    var website: String?
    var contactPhone: String?
    var contactEmail: String?
    var yearEstablished: Int?
    var deliveredProjects: Int?

    var isEmpty: Bool {
        [companyName, about, website, contactPhone, contactEmail].allSatisfy { $0?.nilIfEmpty == nil }
            && yearEstablished == nil && deliveredProjects == nil
    }
}

/// Everything the sheet edits, sent every time.
///
/// The numeric fields are Strings because a nil would read on the server as
/// "leave this alone" — there would be no way to clear a field once set. An
/// empty string is sent instead, which the backend stores as NULL. Phone is
/// absent on purpose: it is the login identity, and moving it belongs with the
/// OTP that owns it.
struct BuilderProfileUpdateRequest: Encodable {
    let fullName: String
    let email: String
    let companyName: String
    let about: String
    let website: String
    let contactPhone: String
    let contactEmail: String
    let yearEstablished: String
    let deliveredProjects: String
}

@MainActor
final class BuilderSettingsModel: ObservableObject {
    @Published var profile: BuilderProfile?
    @Published var loading = true
    @Published var saving = false
    @Published var error: String?
    @Published var message: String?

    private var builderId = 0

    func load(builderId: Int) async {
        self.builderId = builderId
        loading = profile == nil
        error = nil
        do { profile = try await APIClient.shared.get("/builder/\(builderId)/profile") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    func save(_ body: BuilderProfileUpdateRequest) async -> Bool {
        saving = true
        defer { saving = false }
        do {
            try await APIClient.shared.patchVoid("/builder/\(builderId)/profile", body: body)
            message = "Saved"
            await load(builderId: builderId)
            return true
        } catch {
            message = authMessage(error)
            return false
        }
    }
}

struct BuilderSettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var appLock: AppLockManager
    @StateObject private var model = BuilderSettingsModel()
    @State private var editing = false

    private var name: String? { model.profile?.fullName ?? auth.user?.fullName }
    private var email: String? { model.profile?.email ?? auth.user?.email }
    private var phone: String? { model.profile?.phone ?? auth.user?.phone }
    private var company: BuilderInfo? { model.profile?.builder }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                profileCard
                accountCard
                companyCard
                securityCard
                aboutCard
                signOutButton
            }
            .padding(16)
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .sheet(isPresented: $editing) {
            EditBuilderProfileSheet(
                name: name ?? "", email: email ?? "", phone: phone ?? "",
                company: company, saving: model.saving
            ) { body in
                Task { if await model.save(body) { editing = false } }
            }
        }
        .alert("Settings", isPresented: Binding(get: { model.message != nil },
                                                set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            // On white card stock the white ring the branded headers use would
            // simply vanish, so this one takes the card border.
            AccountAvatar(size: 64, ring: .dealioCardBorder)
            VStack(alignment: .leading, spacing: 2) {
                Text(name ?? "Builder").font(.headline).foregroundStyle(Color.dealioTextPrimary)
                Text(company?.companyName?.nilIfEmpty ?? "Builder account")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTeal)
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader("Account")
            InfoLine("Name", name ?? "—")
            InfoLine("Phone", phone ?? "—")
            InfoLine("Email", email?.nilIfEmpty ?? "—")
            InfoLine("Role", "Builder")
            if let id = auth.builderId { InfoLine("Builder ID", "\(id)") }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var companyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader("Company")
            if let error = model.error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).font(.caption).foregroundStyle(Color.dealioTextSecondary)
                    Button("Try again") {
                        Task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
                    }
                    .font(.caption.weight(.semibold))
                }
            } else if model.loading {
                Text("Loading your company details…")
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            } else if company == nil || company?.isEmpty == true {
                // `InfoLine` draws nothing for a blank value, so a builder who has
                // filled in none of these would get a heading over empty space.
                Text("Nothing added yet. Tap Edit to add your company name and what you've delivered.")
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let company {
                InfoLine("Company", company.companyName)
                InfoLine("Website", company.website)
                InfoLine("Established", company.yearEstablished.map(String.init))
                InfoLine("Projects delivered", company.deliveredProjects.map(String.init))
                InfoLine("Contact phone", company.contactPhone)
                InfoLine("Contact email", company.contactEmail)
                if let about = company.about?.trimmedOrNil {
                    Text(about)
                        .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Security")
            AppLockToggle()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("About")
            InfoLine("App", "Dealio for Builders")
            InfoLine("Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var signOutButton: some View {
        Button { auth.logout() } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dealioError)
                .frame(maxWidth: .infinity).frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.dealioError.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func cardHeader(_ title: String) -> some View {
        HStack {
            SectionLabel(title)
            Spacer()
            if model.loading {
                ProgressView().controlSize(.mini)
            } else {
                Button("Edit") { editing = true }
                    .font(.caption.weight(.semibold))
            }
        }
    }
}

private struct EditBuilderProfileSheet: View {
    let name: String
    let email: String
    let phone: String
    let company: BuilderInfo?
    let saving: Bool
    let onSave: (BuilderProfileUpdateRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var emailField = ""
    @State private var companyName = ""
    @State private var about = ""
    @State private var website = ""
    @State private var contactPhone = ""
    @State private var contactEmail = ""
    @State private var yearEstablished = ""
    @State private var deliveredProjects = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Your full name", text: $fullName).textContentType(.name)
                    if fullName.trimmedOrNil == nil {
                        Text("Add a name so buyers know who they're dealing with.")
                            .font(.caption).foregroundStyle(Color.dealioError)
                    }
                    TextField("you@company.com", text: $emailField)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    // Phone is the login identity; moving it belongs with the OTP
                    // that owns it, so it is shown and not edited here.
                    InfoLine("Phone", phone.nilIfEmpty ?? "—")
                }
                Section("Company") {
                    TextField("e.g. Prestige Estates Ltd.", text: $companyName)
                    TextField("A line about the company and its track record",
                              text: $about, axis: .vertical).lineLimit(2...5)
                    TextField("https://yourcompany.com", text: $website)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                    TextField("Year established — e.g. 1996", text: $yearEstablished)
                        .keyboardType(.numberPad)
                    TextField("Projects delivered — e.g. 42", text: $deliveredProjects)
                        .keyboardType(.numberPad)
                    TextField("Sales line buyers can call", text: $contactPhone)
                        .keyboardType(.phonePad)
                    TextField("sales@yourcompany.com", text: $contactEmail)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save changes") {
                        onSave(BuilderProfileUpdateRequest(
                            fullName: fullName.trimmingCharacters(in: .whitespaces),
                            email: emailField.trimmingCharacters(in: .whitespaces),
                            companyName: companyName.trimmingCharacters(in: .whitespaces),
                            about: about.trimmingCharacters(in: .whitespaces),
                            website: website.trimmingCharacters(in: .whitespaces),
                            contactPhone: contactPhone.trimmingCharacters(in: .whitespaces),
                            contactEmail: contactEmail.trimmingCharacters(in: .whitespaces),
                            yearEstablished: yearEstablished.filter(\.isNumber),
                            deliveredProjects: deliveredProjects.filter(\.isNumber)
                        ))
                    }
                    .disabled(saving || fullName.trimmedOrNil == nil)
                }
            }
            .onAppear {
                fullName = name
                emailField = email
                companyName = company?.companyName ?? ""
                about = company?.about ?? ""
                website = company?.website ?? ""
                contactPhone = company?.contactPhone ?? ""
                contactEmail = company?.contactEmail ?? ""
                yearEstablished = company?.yearEstablished.map(String.init) ?? ""
                deliveredProjects = company?.deliveredProjects.map(String.init) ?? ""
            }
        }
    }
}
