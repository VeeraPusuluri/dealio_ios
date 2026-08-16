import SwiftUI
import PhotosUI

/// The signed-in person's picture, and the machinery to change it.
///
/// Held against `AuthStore` rather than any one screen's model, because the
/// picture belongs to the account rather than to a role: the buyer's profile
/// page, the partner's credential and the builder's settings all draw the same
/// thing from the same place.
///
/// The two targets do different things, which is the whole point of having two:
/// the **picture** opens it full screen, the **badge** opens the picker to
/// replace it. With no photo yet there is nothing to view, so the picture falls
/// back to opening the picker — an empty avatar's only useful action is filling
/// it.
///
/// Falls back to the person's initials rather than a grey silhouette: an empty
/// avatar should still say who it belongs to.
struct ProfileAvatarView: View {
    var size: CGFloat = 88
    var ringColor: Color = .white.opacity(0.35)
    var badgeColor: Color = .dealioTeal

    @EnvironmentObject private var auth: AuthStore
    @State private var picked: PhotosPickerItem?
    @State private var picking = false
    @State private var viewing = false
    @State private var uploading = false
    @State private var message: String?

    private var name: String? { auth.user?.fullName }
    private var photoURL: URL? { auth.user?.avatarURL }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                if photoURL != nil { viewing = true } else { picking = true }
            } label: {
                picture
            }
            .buttonStyle(.plain)
            .disabled(uploading)

            // The badge is what makes the picture look changeable — a bare
            // circle reads as decoration, and nobody taps decoration.
            Button { picking = true } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: size / 7.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size / 3.2, height: size / 3.2)
                    .background(badgeColor, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .disabled(uploading)
        }
        .frame(width: size, height: size)
        .photosPicker(isPresented: $picking, selection: $picked, matching: .images)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .fullScreenCover(isPresented: $viewing) {
            if let photoURL {
                FullScreenPhoto(
                    url: photoURL,
                    label: name,
                    canRemove: true,
                    onChange: { viewing = false; picking = true },
                    onRemove: { viewing = false; Task { await remove() } },
                    onDismiss: { viewing = false }
                )
            }
        }
        .alert("Profile picture", isPresented: .constant(message != nil)) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var picture: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [.dealioTealBright, .dealioTeal],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
            if uploading {
                ProgressView().tint(.white)
            } else if let photoURL {
                AsyncImage(url: photoURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().tint(.white)
                }
                .clipShape(Circle())
            } else {
                Text(initialsOf(name ?? "?"))
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size - 8, height: size - 8)
        .clipShape(Circle())
        .padding(4)
        .overlay(Circle().strokeBorder(ringColor, lineWidth: 2))
    }

    private func upload(_ item: PhotosPickerItem) async {
        picked = nil
        uploading = true
        defer { uploading = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            message = "Could not read that image."
            return
        }
        // The picker hands back whatever the library holds; name the part after
        // the bytes rather than after the picker, so the server stores the right
        // extension.
        let (ext, mime) = Self.imageType(of: data)
        do {
            try await auth.uploadAvatar(data: data, fileName: "avatar.\(ext)", mimeType: mime)
        } catch {
            message = authMessage(error)
        }
    }

    private func remove() async {
        uploading = true
        defer { uploading = false }
        do { try await auth.removeAvatar() }
        catch { message = authMessage(error) }
    }

    /// Sniffs the format from the first bytes — PNG and HEIC both come out of
    /// the photo library, and calling everything `.jpg` mislabels them.
    private static func imageType(of data: Data) -> (ext: String, mime: String) {
        let header = [UInt8](data.prefix(12))
        if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return ("png", "image/png") }
        if header.count >= 12, Array(header[4..<8]) == Array("ftyp".utf8) {
            return ("heic", "image/heic")
        }
        if header.count >= 12, Array(header[8..<12]) == Array("WEBP".utf8) {
            return ("webp", "image/webp")
        }
        return ("jpg", "image/jpeg")
    }
}

/// The signed-in person's picture, read-only — for heroes and toolbars, where
/// the avatar identifies rather than invites a change.
///
/// Falls back to initials, and draws from the same `AuthStore` copy the editable
/// avatar writes to, so a new photo appears here the moment it is set rather
/// than after a re-login.
struct AccountAvatar: View {
    var size: CGFloat = 48
    var tint: Color = .brandTeal

    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Group {
            if let url = auth.user?.avatarURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    InitialsAvatar(name: auth.user?.fullName, tint: tint, size: size)
                }
            } else {
                InitialsAvatar(name: auth.user?.fullName, tint: tint, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// The profile picture, big.
///
/// Fitted rather than cropped — the avatar everywhere else is a circle with the
/// edges taken off, so the one place you open it deliberately is the one place
/// the whole photo should be visible.
struct FullScreenPhoto: View {
    let url: URL
    var label: String?
    var canRemove = false
    var onChange: () -> Void
    var onRemove: () -> Void = {}
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Tapping the backdrop closes, which is what every photo viewer on
            // the phone already does.
            Color.black.opacity(0.94).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                }
                .padding(.horizontal, 20)

                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView().tint(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 20)

                HStack(spacing: 12) {
                    Button(action: onChange) {
                        Text("Change photo")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(.white.opacity(0.14), in: Capsule())
                    }
                    if canRemove {
                        Button(action: onRemove) {
                            Text("Remove")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .background(.white.opacity(0.14), in: Capsule())
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.top, 20)
        }
    }
}
