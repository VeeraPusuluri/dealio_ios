import SwiftUI
import PhotosUI

/// The credential, presented on its own.
///
/// There is no sheet chrome around it — no white panel, no title bar. Tapping
/// the portrait on the home screen produces the card and nothing else, so the
/// gesture reads as taking out your card rather than opening a settings sheet.
/// The three actions sit below it as plain engraved labels, deliberately quiet:
/// the card is the content.
struct CpIdentitySheet: View {
    let profile: CpProfile?
    /// Falls back to the signed-in account when the profile hasn't loaded.
    let fallbackName: String
    let onViewProfile: () -> Void

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var picked: PhotosPickerItem?
    @State private var picking = false
    @State private var uploading = false
    @State private var errorMessage: String?
    @State private var sharing = false

    private var name: String { profile?.fullName ?? fallbackName }
    private var tier: String { profile?.cp?.tier ?? "Silver" }
    private var metal: TierMetal { metalFor(tier) }
    private var builders: [CpAuthorizedBuilder] { profile?.authorizedBuilders ?? [] }

    /// The picture comes from the signed-in account, not the CP row: it belongs
    /// to the person, so it is the same photo their profile page and the
    /// buyer-facing screens draw.
    private var photoURL: URL? {
        auth.user?.avatarURL ?? AppConfig.resolveAssetURL(profile?.cp?.photoUrl)
    }

    var body: some View {
        ZStack {
            // Presented over a full-screen cover rather than in a sheet, so the
            // card floats on a scrim the way Android's dialog does instead of
            // riding up on a grey panel with its own chrome.
            Color.black.opacity(0.72).ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 12) {
                CpCredentialCard(
                    name: name,
                    tier: tier,
                    photoURL: photoURL,
                    phone: profile?.phone ?? auth.user?.phone,
                    city: profile?.cp?.city,
                    reraNumber: profile?.cp?.reraNumber,
                    authorizedBuilders: builders,
                    partnerId: profile?.cp?.id,
                    uploading: uploading,
                    onChangePhoto: { picking = true }
                )

                if builders.isEmpty {
                    Text("No builder authorisations yet. When a builder authorises you, it appears on your card.")
                        .font(.system(size: 11))
                        .foregroundStyle(metal.face.opacity(0.70))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                CredentialActionBar {
                    CredentialAction("Close", .white.opacity(0.60)) { dismiss() }
                    CredentialAction("Share", metal.face) { sharing = true }
                    CredentialAction("View profile", metal.face) {
                        dismiss()
                        onViewProfile()
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
        }
        .presentationBackground(.clear)
        .photosPicker(isPresented: $picking, selection: $picked, matching: .images)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .sheet(isPresented: $sharing) {
            ShareSheet(items: [credentialShareText])
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        picked = nil
        uploading = true
        defer { uploading = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "Could not read that image."
            return
        }
        do {
            try await auth.uploadAvatar(data: data, fileName: "avatar.jpg", mimeType: "image/jpeg")
            errorMessage = nil
        } catch {
            errorMessage = authMessage(error)
        }
    }

    /// What a partner sends a customer to prove who they are.
    ///
    /// Written as a message someone would actually paste into a chat — no field
    /// labels, no "Dealio profile" preamble — because it is read by a customer,
    /// not filled in by the partner. The builder authorisation leads, since that
    /// is the part the customer cannot verify for themselves.
    private var credentialShareText: String {
        var lines = [name]
        if builders.isEmpty {
            lines.append("\(tier) Partner on Dealio")
        } else {
            lines.append(contentsOf: builders.map { "Authorised channel partner for \($0.companyName)" })
        }
        if let city = profile?.cp?.city, !city.isEmpty { lines.append(city) }
        if let rera = profile?.cp?.reraNumber, !rera.isEmpty { lines.append("RERA \(rera)") }
        if let phone = profile?.phone ?? auth.user?.phone, !phone.isEmpty { lines.append(phone) }
        return lines.joined(separator: "\n")
    }
}

/// Hands text or a URL to the system share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
