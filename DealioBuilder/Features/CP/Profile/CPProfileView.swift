import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@MainActor
final class CPProfileModel: ObservableObject {
    @Published var profile: CpProfile?
    @Published var loading = true
    @Published var uploadingDoc: String?
    @Published var sendingOtp = false
    @Published var verifyingOtp = false
    @Published var saving = false
    @Published var otpSent = false
    @Published var toast: String?

    func load(cpUserId: Int) async {
        loading = profile == nil
        profile = try? await APIClient.shared.get("/cp/\(cpUserId)/profile")
        loading = false
    }

    func uploadDocument(docType: String, fileURL: URL, cpUserId: Int) async {
        uploadingDoc = docType
        defer { uploadingDoc = nil }
        guard let data = try? Data(contentsOf: fileURL) else {
            toast = "Couldn't read the selected file"
            return
        }
        let ext = fileURL.pathExtension.lowercased()
        let mimeType = ext == "pdf" ? "application/pdf" : ext == "png" ? "image/png" : "image/jpeg"
        do {
            let _: CpDocumentUploadResponse = try await APIClient.shared.upload(
                "/cp/\(cpUserId)/documents", fileData: data, fileName: "\(docType).\(ext)",
                mimeType: mimeType, fields: ["docType": docType]
            )
            toast = "Document uploaded — pending review"
            await load(cpUserId: cpUserId)
        } catch {
            toast = "Failed to upload document"
        }
    }

    /// Replaces the partner's portrait.
    ///
    /// The avatar is the *account's*, not the CP profile's — one photo follows
    /// the person across every portal — so it goes through `AuthStore`, which
    /// also refreshes the session every other screen reads its initials from.
    func uploadAvatar(auth: AuthStore, data: Data) async {
        uploadingDoc = "avatar"
        defer { uploadingDoc = nil }
        do {
            try await auth.uploadAvatar(data: data, fileName: "avatar.jpg", mimeType: "image/jpeg")
            toast = "Photo updated"
            await load(cpUserId: auth.user?.id ?? 0)
        } catch { toast = authMessage(error) }
    }

    /// Saves the details a partner can change themselves. The phone is the login
    /// identity and is verified through OTP, so it is not on this form.
    func saveProfile(cpUserId: Int, _ request: CPService.ProfileUpdateRequest) async -> Bool {
        saving = true
        defer { saving = false }
        do {
            try await CPService.updateProfile(cpUserId: cpUserId, request)
            toast = "Profile saved"
            await load(cpUserId: cpUserId)
            return true
        } catch {
            toast = authMessage(error)
            return false
        }
    }

    func sendPhoneOtp(phone: String) async {
        sendingOtp = true
        defer { sendingOtp = false }
        struct Body: Encodable { let phone: String }
        do {
            let _: EmptyResponse = try await APIClient.shared.post("/cp/verify-phone/send-otp", body: Body(phone: phone))
            otpSent = true
            toast = "OTP sent to \(phone)"
        } catch {
            toast = "Failed to send OTP"
        }
    }

    func verifyPhoneOtp(phone: String, otp: String, cpUserId: Int) async -> Bool {
        verifyingOtp = true
        defer { verifyingOtp = false }
        struct Body: Encodable { let phone: String; let otp: String }
        struct Result: Decodable { let phoneVerified: Bool }
        do {
            let _: Result = try await APIClient.shared.post("/cp/\(cpUserId)/verify-phone", body: Body(phone: phone, otp: otp))
            otpSent = false
            toast = "Phone verified"
            await load(cpUserId: cpUserId)
            return true
        } catch {
            toast = "Invalid or expired OTP"
            return false
        }
    }
}

/// A JSON response with no meaningful payload (`{ "message": "..." }`).
struct EmptyResponse: Decodable {}

struct CPProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPProfileModel()
    @State private var docPickerFor: String?
    @State private var showPhoneVerify = false
    @State private var editing = false
    @State private var pickingPhoto = false
    @State private var photoPick: PhotosPickerItem?

    private var cpUserId: Int { auth.user?.id ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    let cp = model.profile?.cp
                    let name = model.profile?.fullName ?? auth.user?.fullName ?? "Partner"

                    // The credential — the same facts as a header, rendered as
                    // the artifact a partner holds up to a customer.
                    CPCredentialCard(
                        name: name,
                        tier: cp?.tier ?? "Silver",
                        photoUrl: cp?.photoUrl ?? auth.user?.avatarUrl,
                        phone: model.profile?.phone ?? auth.user?.phone,
                        city: cp?.city,
                        reraNumber: cp?.reraNumber,
                        authorizedBuilders: model.profile?.authorizedBuilders ?? [],
                        partnerId: model.profile?.id ?? auth.user?.id,
                        uploadingPhoto: model.uploadingDoc == "avatar",
                        onChangePhoto: { pickingPhoto = true }
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // What they have earned, which is the number a partner opens
                    // this page to check.
                    HStack(spacing: 10) {
                        earningsTile("Total earned", Money.inr(cp?.totalEarnings ?? 0), .green)
                        earningsTile("Pending", Money.inr(cp?.pendingCommission ?? 0), .orange)
                        earningsTile("Deals", "\(cp?.totalDeals ?? 0)", .brandTeal)
                    }
                    .padding(.horizontal)

                    // Details
                    VStack(spacing: 0) {
                        HStack {
                            SectionHeader(title: "Details")
                            Spacer()
                            Button("Edit") { editing = true }.font(.caption.weight(.semibold))
                        }
                        .padding(.vertical, 10)
                        InfoRow(label: "Phone", value: model.profile?.phone ?? auth.user?.phone ?? "—")
                        InfoRow(label: "Email", value: model.profile?.email ?? "—")
                        InfoRow(label: "City", value: cp?.city ?? "—")
                        InfoRow(label: "RERA", value: cp?.reraNumber ?? "—")
                        if let bio = cp?.bio?.trimmedOrNil {
                            Text(bio)
                                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 16).cardSurface().padding(.horizontal)

                    // Builders who have formally authorised this partner to
                    // represent them — the thing a buyer is really asking about
                    // when they ask whether a partner is "official".
                    if let builders = model.profile?.authorizedBuilders, !builders.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Authorised by").padding(.vertical, 10)
                            ForEach(builders) { builder in
                                HStack {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                    Text(builder.companyName.nilIfEmpty ?? "Builder")
                                        .font(.subheadline)
                                    Spacer()
                                    if let since = builder.authorizedAt?.prefix(10), !since.isEmpty {
                                        Text(String(since))
                                            .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                                    }
                                }
                                .padding(.vertical, 9)
                            }
                        }
                        .padding(.horizontal, 16).cardSurface().padding(.horizontal)
                    }

                    // Verification
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Verification").padding(.vertical, 10)
                        VerifyRow(label: "Phone", verified: cp?.phoneVerified ?? false, actionLabel: "Verify") {
                            showPhoneVerify = true
                        }
                        DocVerifyRow(
                            label: "Aadhaar", verified: cp?.aadhaarVerified ?? false,
                            hasDoc: (cp?.aadhaarUrl?.isEmpty == false), uploading: model.uploadingDoc == "aadhaar"
                        ) { docPickerFor = "aadhaar" }
                        DocVerifyRow(
                            label: "PAN", verified: cp?.panVerified ?? false,
                            hasDoc: (cp?.panUrl?.isEmpty == false), uploading: model.uploadingDoc == "pan"
                        ) { docPickerFor = "pan" }
                        DocVerifyRow(
                            label: "RERA certificate", verified: cp?.reraVerified ?? false,
                            hasDoc: (cp?.reraUrl?.isEmpty == false), uploading: model.uploadingDoc == "rera"
                        ) { docPickerFor = "rera" }
                    }
                    .padding(.horizontal, 16).cardSurface().padding(.horizontal)

                    // Security
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Security").padding(.vertical, 10)
                        AppLockToggle()
                    }
                    .padding(.horizontal, 16).cardSurface().padding(.horizontal)

                    Button(role: .destructive) { auth.logout() } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Profile")
            .task { await model.load(cpUserId: cpUserId) }
            .fileImporter(
                isPresented: Binding(get: { docPickerFor != nil }, set: { if !$0 { docPickerFor = nil } }),
                allowedContentTypes: [.image, .pdf]
            ) { result in
                guard let docType = docPickerFor else { return }
                docPickerFor = nil
                if case .success(let url) = result {
                    Task { await model.uploadDocument(docType: docType, fileURL: url, cpUserId: cpUserId) }
                }
            }
            .photosPicker(isPresented: $pickingPhoto, selection: $photoPick, matching: .images)
            .onChange(of: photoPick) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                    photoPick = nil
                    await model.uploadAvatar(auth: auth, data: data)
                }
            }
            .sheet(isPresented: $editing) {
                EditCPProfileSheet(profile: model.profile, saving: model.saving) { request in
                    Task { if await model.saveProfile(cpUserId: cpUserId, request) { editing = false } }
                }
            }
            .sheet(isPresented: $showPhoneVerify) {
                PhoneVerifySheet(
                    phone: model.profile?.phone ?? auth.user?.phone ?? "",
                    model: model, cpUserId: cpUserId
                )
            }
            .alert(model.toast ?? "", isPresented: Binding(get: { model.toast != nil }, set: { if !$0 { model.toast = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

extension CPProfileView {
    fileprivate func earningsTile(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold)).tracking(0.5)
                .foregroundStyle(Color.dealioTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardSurface(cornerRadius: 14)
    }
}

private struct EditCPProfileSheet: View {
    let profile: CpProfile?
    let saving: Bool
    let onSave: (CPService.ProfileUpdateRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var email = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var rera = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Full name", text: $fullName).textContentType(.name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    // Phone is the login identity and is changed through OTP, so
                    // it is shown on the page and not edited here.
                    InfoLine("Phone", profile?.phone?.nilIfEmpty ?? "—")
                }
                Section("How buyers see you") {
                    TextField("City you work in", text: $city)
                    TextField("A line about your track record", text: $bio, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("RERA registration number", text: $rera)
                        .textInputAutocapitalization(.characters)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        onSave(.init(
                            fullName: fullName.trimmedOrNil, email: email.trimmedOrNil,
                            city: city.trimmedOrNil, bio: bio.trimmedOrNil,
                            reraNumber: rera.trimmedOrNil
                        ))
                    }
                    .disabled(saving)
                }
            }
            .onAppear {
                fullName = profile?.fullName ?? ""
                email = profile?.email ?? ""
                city = profile?.cp?.city ?? ""
                bio = profile?.cp?.bio ?? ""
                rera = profile?.cp?.reraNumber ?? ""
            }
        }
    }
}

private struct PhoneVerifySheet: View {
    let phone: String
    @ObservedObject var model: CPProfileModel
    let cpUserId: Int
    @State private var otp = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("We'll send a one-time code to \(phone)")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.top, 24)

                if model.otpSent {
                    TextField("Enter OTP", text: $otp)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        if model.otpSent {
                            if await model.verifyPhoneOtp(phone: phone, otp: otp, cpUserId: cpUserId) { dismiss() }
                        } else {
                            await model.sendPhoneOtp(phone: phone)
                        }
                    }
                } label: {
                    Text(model.otpSent ? "Verify" : "Send OTP")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.dealioOrange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
                .disabled(model.sendingOtp || model.verifyingOtp)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Verify Phone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).lineLimit(1)
        }
        .font(.subheadline).padding(.vertical, 13)
        .overlay(Divider(), alignment: .bottom)
    }
}

private struct VerifyRow: View {
    let label: String
    let verified: Bool
    var actionLabel: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            if !verified, let actionLabel, let onAction {
                Button(actionLabel, action: onAction)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.dealioOrange)
            } else {
                Label(verified ? "Verified" : "Pending", systemImage: verified ? "checkmark.seal.fill" : "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(verified ? .green : .secondary)
            }
        }
        .padding(.vertical, 12)
        .overlay(Divider(), alignment: .bottom)
    }
}

private struct DocVerifyRow: View {
    let label: String
    let verified: Bool
    let hasDoc: Bool
    let uploading: Bool
    let onUpload: () -> Void

    var body: some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            if uploading {
                ProgressView().controlSize(.small)
            } else if verified {
                Label("Verified", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.green)
            } else if hasDoc {
                Label("Under review", systemImage: "clock")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            } else {
                Button("Upload", action: onUpload)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.dealioOrange)
            }
        }
        .padding(.vertical, 12)
        .overlay(Divider(), alignment: .bottom)
    }
}
