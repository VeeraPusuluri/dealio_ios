import SwiftUI
import PhotosUI

/// The signed-in user's photo, with the picker that replaces it.
///
/// The avatar belongs to the *account*, not to any one portal — one photo
/// follows the person whether they are looking at the builder settings, the CP
/// credential or the buyer profile — so it is uploaded through `AuthStore` and
/// every screen reads the same value back. Mirrors Android's
/// `ui/components/ProfileAvatar.kt`.
struct AccountAvatar: View {
    var size: CGFloat = 72
    /// Ring colour. On a white card the white ring the branded headers use
    /// simply vanishes, so callers on light surfaces pass the card border.
    var ring: Color = .white.opacity(0.25)
    var tint: Color = .brandTeal
    /// When false the avatar is a portrait and nothing more — no camera badge,
    /// no picker.
    var editable = true

    @EnvironmentObject private var auth: AuthStore
    @State private var picking = false
    @State private var pick: PhotosPickerItem?
    @State private var uploading = false
    @State private var removing = false
    @State private var message: String?

    private var name: String? { auth.user?.fullName }
    private var photoURL: URL? { auth.user?.avatarURL }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                // Initials first, photo on top: a URL that fails to load leaves
                // the initials showing rather than an empty circle.
                InitialsAvatar(name: name, tint: tint, size: size)
                if let photoURL, !uploading {
                    AsyncImage(url: photoURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                }
                if uploading {
                    Circle().fill(Color.dealioNavyDeep.opacity(0.5)).frame(width: size, height: size)
                    ProgressView().tint(.white)
                }
            }
            .overlay(Circle().strokeBorder(ring, lineWidth: 1))

            if editable, !uploading {
                Menu {
                    Button("Choose a photo", systemImage: "photo") { picking = true }
                    if photoURL != nil {
                        Button("Remove photo", systemImage: "trash", role: .destructive) {
                            Task { await remove() }
                        }
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.16))
                        .foregroundStyle(.white)
                        .frame(width: size * 0.32, height: size * 0.32)
                        .background(tint, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                }
                .accessibilityLabel("Change photo")
            }
        }
        .photosPicker(isPresented: $picking, selection: $pick, matching: .images)
        .onChange(of: pick) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                pick = nil
                await upload(data)
            }
        }
        .alert("Photo", isPresented: Binding(get: { message != nil },
                                             set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func upload(_ data: Data) async {
        uploading = true
        defer { uploading = false }
        do {
            try await auth.uploadAvatar(data: data, fileName: "avatar.jpg", mimeType: "image/jpeg")
        } catch { message = authMessage(error) }
    }

    private func remove() async {
        removing = true
        defer { removing = false }
        do { try await auth.removeAvatar() }
        catch { message = authMessage(error) }
    }
}
