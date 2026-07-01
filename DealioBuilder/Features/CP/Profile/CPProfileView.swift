import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CPProfileModel: ObservableObject {
    @Published var profile: CpProfile?
    @Published var loading = true
    @Published var uploadingDoc: String?
    @Published var sendingOtp = false
    @Published var verifyingOtp = false
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

    private var cpUserId: Int { auth.user?.id ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    let cp = model.profile?.cp
                    let name = model.profile?.fullName ?? auth.user?.fullName ?? "Partner"

                    // Header
                    VStack(spacing: 12) {
                        InitialsAvatar(name: name, size: 72)
                        VStack(spacing: 4) {
                            Text(name).font(.title3.weight(.bold))
                            if let tier = cp?.tier {
                                Text("\(tier) Partner").font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 3)
                                    .background(Color.dealioOrange.opacity(0.15), in: Capsule())
                                    .foregroundStyle(Color.dealioOrange)
                            }
                        }
                    }
                    .padding(.top, 16)

                    // Details
                    VStack(spacing: 0) {
                        InfoRow(label: "Phone", value: model.profile?.phone ?? auth.user?.phone ?? "—")
                        InfoRow(label: "Email", value: model.profile?.email ?? "—")
                        InfoRow(label: "City", value: cp?.city ?? "—")
                        InfoRow(label: "RERA", value: cp?.reraNumber ?? "—")
                    }
                    .padding(.horizontal, 16).cardSurface().padding(.horizontal)

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
