import SwiftUI
import PhotosUI

// MARK: - The credential
//
// A channel partner's standing is already a metal hierarchy in the data —
// Silver, Gold, Platinum — and a builder authorisation is an endorsement they
// show a customer to prove they can sell. So the CP's identity is rendered as
// one artifact: an engraved, foil-edged card whose metal IS their tier.
//
// The same card is the hero of the profile page and the whole content of the
// viewer behind the portrait, so opening it reads as "showing your card" rather
// than "a sheet appeared". Everything around it stays plain white — the card is
// the only place this app spends any shine. Mirrors Android's `ui/cp/CpCredential.kt`.

/// The foil a tier is struck in.
struct TierMetal {
    let face: Color
    let edge: Color
    let label: String

    static let silver = TierMetal(face: Color(hex: 0xB6C0CE), edge: Color(hex: 0x8794A6), label: "Silver")
    static let gold = TierMetal(face: Color(hex: 0xE3A94B), edge: Color(hex: 0xA9762A), label: "Gold")
    static let platinum = TierMetal(face: Color(hex: 0xCFE4EC), edge: Color(hex: 0x6FA8B8), label: "Platinum")

    static func forTier(_ tier: String?) -> TierMetal {
        switch tier?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "gold": return .gold
        case "platinum": return .platinum
        default: return .silver
        }
    }
}

/// A partner's ID, struck the way a card number is: four digits, zero-padded.
///
/// The raw value is a database row number, and "7" sitting next to a RERA number
/// reads as a placeholder rather than something issued. Padding gives every
/// partner an ID of the same shape. Anyone past four digits prints in full —
/// this widens ids, it never truncates them.
func formatPartnerId(_ id: Int) -> String {
    String(format: "%04d", id)
}

/// Engraved register: small, letterspaced caps. Every label on the card.
struct EngravedLabel: View {
    let text: String
    var color: Color
    var size: CGFloat = 10

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

/// The CP's credential card.
///
/// The portrait and the camera badge are two different gestures, not one target
/// hit twice: tapping a face shows you the face, and the badge — the only thing
/// wearing a camera — is what replaces it. Wiring both to the picker meant a
/// partner could never look at their own photo without being asked for a new
/// one. Until there *is* a photo the portrait falls through to the picker, since
/// an empty viewer is not worth opening.
struct CPCredentialCard: View {
    let name: String
    let tier: String
    var photoUrl: String?
    var phone: String?
    var city: String?
    var reraNumber: String?
    var authorizedBuilders: [CpAuthorizedBuilder] = []
    var partnerId: Int?
    var uploadingPhoto = false
    var onChangePhoto: (() -> Void)?

    @State private var viewingPhoto = false

    private var metal: TierMetal { TierMetal.forTier(tier) }
    // The backend stores the upload URL with whatever scheme it saw at upload
    // time — usually plain http, which ATS blocks. Left unresolved the portrait
    // silently falls back to initials forever.
    private var resolvedPhoto: URL? { AppConfig.resolveAssetURL(photoUrl) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.dealioNavyDeep, .dealioNavyPrimary, .dealioNavyDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            // A single diagonal sheen across the face. One sweep reads as struck
            // metal; several read as a gradient demo.
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: metal.face.opacity(0.10), location: 0.42),
                .init(color: metal.face.opacity(0.03), location: 0.52),
                .init(color: .clear, location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    portrait
                    VStack(alignment: .leading, spacing: 2) {
                        EngravedLabel(text: "\(metal.label) Partner", color: metal.face)
                            .padding(.bottom, 2)
                        Text(name)
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let sub = [phone?.nilIfEmpty, city?.nilIfEmpty]
                            .compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                            Text(sub)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }

                // The ID belongs on the face of the card, not two taps deep
                // behind the portrait. It is the one thing every partner has —
                // tier and RERA are optional, an ID is not.
                if let partnerId {
                    plateRow("CP ID", formatPartnerId(partnerId), tracking: 1)
                        .padding(.top, 14)
                }
                if let rera = reraNumber?.nilIfEmpty {
                    plateRow("RERA", rera)
                        .padding(.top, partnerId != nil ? 8 : 14)
                }

                if !authorizedBuilders.isEmpty {
                    // Hairline rule in the tier metal separates who they are from
                    // who vouches for them — the two halves of a credential.
                    Rectangle()
                        .fill(metal.edge.opacity(0.35))
                        .frame(height: 1)
                        .padding(.top, 16)

                    EngravedLabel(text: "Authorised CP for", color: metal.face.opacity(0.75))
                        .padding(.top, 14)

                    ForEach(authorizedBuilders) { builder in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(metal.face)
                            Text(builder.companyName.nilIfEmpty ?? "Builder")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            // The foil edge is the tier. It is the only hairline on the card, so
            // the metal is legible at a glance without a badge announcing it.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(metal.edge.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .sheet(isPresented: $viewingPhoto) {
            if let resolvedPhoto {
                CredentialPhotoViewer(
                    name: name, photoURL: resolvedPhoto, metal: metal,
                    authorizedBuilders: authorizedBuilders, partnerId: partnerId,
                    onChangePhoto: onChangePhoto.map { change in
                        { viewingPhoto = false; change() }
                    }
                )
            }
        }
    }

    private func plateRow(_ label: String, _ value: String, tracking: CGFloat = 0) -> some View {
        HStack(spacing: 8) {
            EngravedLabel(text: label, color: .white.opacity(0.40))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .tracking(tracking)
                .foregroundStyle(.white.opacity(0.80))
            Spacer(minLength: 0)
        }
    }

    private var portrait: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                // Initials are drawn first and the photo sits on top, so a URL
                // that fails to load leaves the initials showing rather than an
                // empty tile.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.10))
                Text(Fmt.initials(name))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                if let resolvedPhoto, !uploadingPhoto {
                    AsyncImage(url: resolvedPhoto) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if uploadingPhoto {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.dealioNavyDeep.opacity(0.55))
                    ProgressView().tint(metal.face)
                }
            }
            .frame(width: 64, height: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(metal.face.opacity(0.45), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard !uploadingPhoto else { return }
                if resolvedPhoto != nil { viewingPhoto = true } else { onChangePhoto?() }
            }

            if let onChangePhoto, !uploadingPhoto {
                Button(action: onChangePhoto) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dealioNavyDeep)
                        .frame(width: 22, height: 22)
                        .background(metal.face, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Upload photo")
            }
        }
    }
}

/// The portrait, full size.
///
/// No sheet chrome: the photo on the navy field is the content. "Change photo"
/// is repeated here because the one place you can look at the picture is the
/// obvious place to decide you want a different one.
///
/// The plate under the photo carries the two claims a face alone cannot make:
/// who authorised this partner, and the ID that identifies them. Opened on its
/// own the photo proves nothing; with those beneath it, this is something a
/// partner can hold up to a customer as-is.
private struct CredentialPhotoViewer: View {
    let name: String
    let photoURL: URL
    let metal: TierMetal
    let authorizedBuilders: [CpAuthorizedBuilder]
    let partnerId: Int?
    var onChangePhoto: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.dealioNavyDeep.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer(minLength: 0)

                AsyncImage(url: photoURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView().tint(metal.face)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(metal.edge.opacity(0.5), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    if let partnerId {
                        HStack(spacing: 8) {
                            EngravedLabel(text: "CP ID", color: .white.opacity(0.4))
                            Text(formatPartnerId(partnerId))
                                .font(.system(size: 12, weight: .medium)).tracking(1)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    if !authorizedBuilders.isEmpty {
                        EngravedLabel(text: "Authorised CP for", color: metal.face.opacity(0.75))
                        ForEach(authorizedBuilders) { builder in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13)).foregroundStyle(metal.face)
                                Text(builder.companyName.nilIfEmpty ?? "Builder")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    if let onChangePhoto {
                        Button("Change photo", action: onChangePhoto)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.dealioNavyDeep)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(metal.face, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Button("Close") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(24)
        }
    }
}
