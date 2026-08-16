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
// sheet behind the home-screen portrait, so opening it reads as "showing your
// card" rather than "a popup appeared". Everything around it stays plain white
// surfaces — the card is the only place this app spends any shine.

/// The foil a tier is struck in.
struct TierMetal {
    let face: Color
    let edge: Color
    let label: String
}

private let SilverMetal = TierMetal(face: Color(hex: 0xB6C0CE), edge: Color(hex: 0x8794A6), label: "Silver")
private let GoldMetal = TierMetal(face: Color(hex: 0xE3A94B), edge: Color(hex: 0xA9762A), label: "Gold")
private let PlatinumMetal = TierMetal(face: Color(hex: 0xCFE4EC), edge: Color(hex: 0x6FA8B8), label: "Platinum")

func metalFor(_ tier: String?) -> TierMetal {
    switch tier?.trimmingCharacters(in: .whitespaces).lowercased() {
    case "gold": return GoldMetal
    case "platinum": return PlatinumMetal
    default: return SilverMetal
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

    init(_ text: String, _ color: Color, size: CGFloat = 10) {
        self.text = text
        self.color = color
        self.size = size
    }

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
/// on the card wearing a camera — is what replaces it. Wiring both to the picker
/// meant a partner could never look at their own photo without being asked for a
/// new one. Until there *is* a photo the portrait falls through to the picker,
/// since an empty viewer is not worth opening.
struct CpCredentialCard: View {
    let name: String
    let tier: String
    var photoURL: URL?
    var phone: String?
    var city: String?
    var reraNumber: String?
    var authorizedBuilders: [CpAuthorizedBuilder] = []
    var partnerId: Int?
    var uploading = false
    /// `nil` hides the camera badge — the card is then read-only.
    var onChangePhoto: (() -> Void)?

    @State private var viewingPhoto = false

    private var metal: TierMetal { metalFor(tier) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                CredentialPortrait(
                    name: name, photoURL: photoURL, metal: metal, uploading: uploading,
                    onView: photoURL != nil ? { viewingPhoto = true } : onChangePhoto,
                    onChange: onChangePhoto
                )
                VStack(alignment: .leading, spacing: 0) {
                    EngravedLabel("\(metal.label) Partner", metal.face)
                    Spacer().frame(height: 4)
                    Text(name)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    let sub = [phone, city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                    if !sub.isEmpty {
                        Spacer().frame(height: 2)
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            // The ID belongs on the face of the card, not two taps deep behind
            // the portrait. It is the one thing every partner has — tier and
            // RERA are optional, an ID is not — so it leads the plate.
            if let partnerId {
                Spacer().frame(height: 14)
                plateRow("CP ID", formatPartnerId(partnerId), tracking: 1)
            }

            if let rera = reraNumber, !rera.isEmpty {
                Spacer().frame(height: partnerId != nil ? 8 : 14)
                plateRow("RERA", rera)
            }

            if !authorizedBuilders.isEmpty {
                Spacer().frame(height: 16)
                // Hairline rule in the tier metal separates who they are from
                // who vouches for them — the two halves of a credential.
                Rectangle().fill(metal.edge.opacity(0.35)).frame(height: 1)
                Spacer().frame(height: 14)
                EngravedLabel("Authorised CP for", metal.face.opacity(0.75))
                ForEach(authorizedBuilders) { builder in
                    Spacer().frame(height: 6)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(metal.face)
                        Text(builder.companyName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(colors: [.dealioNavyDeep, .dealioNavyPrimary, .dealioNavyDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                // A single diagonal sheen across the face. One sweep reads as
                // struck metal; several read as a gradient demo.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: metal.face.opacity(0.10), location: 0.42),
                        .init(color: metal.face.opacity(0.03), location: 0.52),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // The foil edge is the tier. It is the only hairline on the card, so
        // the metal is legible at a glance without a badge announcing it.
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(metal.edge.opacity(0.55), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .fullScreenCover(isPresented: $viewingPhoto) {
            if let photoURL {
                CredentialPhotoView(
                    name: name, photoURL: photoURL, metal: metal,
                    authorizedBuilders: authorizedBuilders, partnerId: partnerId,
                    onChangePhoto: onChangePhoto.map { change in
                        { viewingPhoto = false; change() }
                    },
                    onDismiss: { viewingPhoto = false }
                )
            }
        }
    }

    private func plateRow(_ label: String, _ value: String, tracking: CGFloat = 0) -> some View {
        HStack(spacing: 8) {
            EngravedLabel(label, .white.opacity(0.40))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .tracking(tracking)
                .foregroundStyle(.white.opacity(0.80))
        }
    }
}

private struct CredentialPortrait: View {
    let name: String
    let photoURL: URL?
    let metal: TierMetal
    let uploading: Bool
    var onView: (() -> Void)?
    var onChange: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button { onView?() } label: {
                ZStack {
                    // Initials are drawn first and the photo sits on top, so a
                    // URL that fails to load leaves the initials showing
                    // instead of an empty tile.
                    Text(initialsOf(name))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    if let photoURL, !uploading {
                        AsyncImage(url: photoURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                    }
                    if uploading {
                        Color.dealioNavyDeep.opacity(0.55)
                        ProgressView().tint(metal.face)
                    }
                }
                .frame(width: 64, height: 64)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(metal.face.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(onView == nil || uploading)

            if let onChange, !uploading {
                Button(action: onChange) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.dealioNavyDeep)
                        .frame(width: 22, height: 22)
                        .background(metal.face, in: Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: 4)
            }
        }
    }
}

/// The portrait, full size.
///
/// No sheet chrome: the photo on the navy field is the content. The plate under
/// it carries the two claims a face alone cannot make — who authorised this
/// partner, and the ID that identifies them. Opened on its own the photo proves
/// nothing; with those beneath it, this is something a partner can hold up to a
/// customer as-is.
struct CredentialPhotoView: View {
    let name: String
    let photoURL: URL
    let metal: TierMetal
    var authorizedBuilders: [CpAuthorizedBuilder] = []
    var partnerId: Int?
    var onChangePhoto: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 12) {
                Spacer(minLength: 0)

                ZStack {
                    // Initials underneath, as on the card, so a photo that
                    // fails to load leaves something face-shaped rather than a
                    // black square.
                    Text(initialsOf(name))
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white.opacity(0.30))
                    AsyncImage(url: photoURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.dealioNavyDeep)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(metal.edge.opacity(0.55), lineWidth: 1))

                if !authorizedBuilders.isEmpty || partnerId != nil {
                    VStack(alignment: .leading, spacing: 0) {
                        if !authorizedBuilders.isEmpty {
                            EngravedLabel("Authorised CP for", metal.face.opacity(0.75))
                            ForEach(authorizedBuilders) { builder in
                                Spacer().frame(height: 6)
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 14)).foregroundStyle(metal.face)
                                    Text(builder.companyName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                }
                            }
                        }
                        if let partnerId {
                            if !authorizedBuilders.isEmpty {
                                Spacer().frame(height: 12)
                                Rectangle().fill(metal.edge.opacity(0.35)).frame(height: 1)
                                Spacer().frame(height: 12)
                            }
                            HStack {
                                EngravedLabel("CP ID", .white.opacity(0.40))
                                Spacer()
                                Text(formatPartnerId(partnerId))
                                    .font(.system(size: 13, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(.white.opacity(0.80))
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dealioNavyDeep.opacity(0.92),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                CredentialActionBar {
                    CredentialAction("Close", .white.opacity(0.60), action: onDismiss)
                    if let onChangePhoto {
                        CredentialAction("Change photo", metal.face, action: onChangePhoto)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
    }
}

/// The quiet field the card's actions sit on. Left bare they sat on whatever
/// showed through the scrim, and engraved caps on a half-lit list are unreadable.
struct CredentialActionBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 2, content: content)
            .padding(.horizontal, 6)
            .background(Color.dealioNavyDeep.opacity(0.88),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CredentialAction: View {
    let title: String
    let color: Color
    let action: () -> Void

    init(_ title: String, _ color: Color, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            EngravedLabel(title, color, size: 11)
                .padding(.horizontal, 12).padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }
}
