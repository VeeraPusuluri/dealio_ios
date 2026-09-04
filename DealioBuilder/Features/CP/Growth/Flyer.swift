import SwiftUI
import UIKit

/// Shareable project flyers.
///
/// A flyer is a real image the CP can drop into a WhatsApp status or an Instagram
/// post, not a block of text. The poster is composed on a fixed 360×450 pt design
/// grid and rendered at 3× so the exported file is exactly 1080×1350 px on every
/// device — the same output whether the CP is on an SE or a Pro Max.
///
/// Commission figures deliberately never appear on any template: these files get
/// forwarded to buyers. Mirrors Android's `ui/cp/growth/Flyer.kt`.

enum FlyerTemplate: String, CaseIterable, Identifiable {
    /// Everything: photo, the full fact sheet, and the walkthrough video link.
    case showcase
    /// The flyer plus the CP's own contact card — the one they send to their own leads.
    case coBranded = "branded"
    /// Project only. For forwarding onward, or posting where contact details don't belong.
    case clean

    var id: String { rawValue }

    var label: String {
        switch self {
        case .showcase: return "Showcase"
        case .coBranded: return "Co-branded"
        case .clean: return "Clean"
        }
    }

    var blurb: String {
        switch self {
        case .showcase: return "Photo, full details and the walkthrough video link"
        case .coBranded: return "Project flyer with your name, phone and RERA on it"
        case .clean: return "Just the project — none of your details on it"
        }
    }

    var heroHeight: CGFloat {
        switch self {
        case .showcase: return 186
        case .coBranded: return 176
        case .clean: return 216
        }
    }
}

/// The design grid. 1080×1350 is the 4:5 portrait size Instagram, WhatsApp status
/// and Facebook all accept unscaled.
enum FlyerSize {
    static let width: CGFloat = 360
    static let height: CGFloat = 450
    static let scale: CGFloat = 3
}

// MARK: - The poster

struct FlyerPoster: View {
    let template: FlyerTemplate
    let project: Project
    let profile: CpProfile?
    /// The hero photograph, already fetched. Passing a decoded image rather than a
    /// URL is what makes the export deterministic: an `AsyncImage` still loading
    /// when the renderer runs would bake a blank rectangle into the JPEG.
    var hero: UIImage?
    /// The CP's tracked share link as a QR, already decoded.
    var qr: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            heroBand

            VStack(alignment: .leading, spacing: 12) {
                priceRow
                facts
                if template != .coBranded,
                   let amenities = (project.amenities ?? []).filter({ !$0.isEmpty }).prefix(4).nilIfEmptyList {
                    Text(amenities.joined(separator: "  ·  "))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dealioTextSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Clean gets no QR on purpose: a tracked link resolves to one CP,
            // which is exactly the detail this template promises not to carry.
            switch template {
            case .showcase: videoBand
            case .coBranded: contactBand
            case .clean: cleanFooter
            }
        }
        .frame(width: FlyerSize.width, height: FlyerSize.height)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    // MARK: Hero

    private var heroBand: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTeal],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let hero {
                Image(uiImage: hero).resizable().scaledToFill()
            } else {
                Image(systemName: "building.2")
                    .font(.system(size: 46))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Scrim so the title stays readable over a bright or busy photo.
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color.dealioNavyDeep.opacity(0.15), location: 0.42),
                .init(color: Color.dealioNavyDeep.opacity(0.88), location: 1),
            ], startPoint: .top, endPoint: .bottom)

            if let status = project.status?.nilIfEmpty {
                VStack {
                    HStack {
                        Text(Fmt.titleCase(status))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color.brandTeal, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(14)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let location = project.whereLine.nilIfEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(location)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
        }
        .frame(height: template.heroHeight)
        .clipped()
    }

    // MARK: Body

    private var priceRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STARTING FROM")
                    .font(.system(size: 9, weight: .bold)).tracking(1)
                    .foregroundStyle(Color.dealioTextSecondary)
                Text(project.priceLow.map { Fmt.compactPrice($0) } ?? "Price on request")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color.dealioTextPrimary)
            }
            Spacer()
            if let builder = project.builderName?.nilIfEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("BY")
                        .font(.system(size: 9, weight: .bold)).tracking(1)
                        .foregroundStyle(Color.dealioTextSecondary)
                    Text(builder)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
                .frame(width: 140, alignment: .trailing)
            }
        }
    }

    /// The fact sheet — any row whose field is missing simply isn't drawn.
    @ViewBuilder
    private var facts: some View {
        let compact = template == .coBranded
        let rows = factRows(compact: compact)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(rows, id: \.0) { label, value in
                    HStack(alignment: .top, spacing: 0) {
                        Text(label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.dealioTextSecondary)
                            .frame(width: 96, alignment: .leading)
                        Text(value)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.dealioTextPrimary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xF6F9FB), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func factRows(compact: Bool) -> [(String, String)] {
        var rows: [(String, String)] = []
        if let configs = (project.configurations ?? []).filter({ !$0.isEmpty }).nilIfEmptyList {
            rows.append(("Configurations", configs.joined(separator: " / ")))
        }
        if let possession = project.possessionDate?.nilIfEmpty {
            rows.append(("Possession", Fmt.date(possession)))
        }
        if !compact {
            if let type = project.projectType?.nilIfEmpty {
                rows.append(("Type", Fmt.titleCase(type)))
            }
            if let total = project.totalUnits, total > 0 {
                let towers = project.towers.flatMap { $0 > 0 ? $0 : nil }
                rows.append(("Scale", towers.map { "\(total) units · \($0) towers" } ?? "\(total) units"))
            }
        }
        if let rera = project.reraNumber?.nilIfEmpty { rows.append(("RERA", rera)) }
        return Array(rows.prefix(compact ? 3 : 5))
    }

    // MARK: Footers

    /// Showcase footer — the walkthrough link, or an invitation to ask for one.
    private var videoBand: some View {
        let video = project.videoUrl?.nilIfEmpty
        return HStack(spacing: 0) {
            Image(systemName: video != nil ? "play.circle" : "calendar")
                .font(.system(size: 24))
                .foregroundStyle(Color(hex: 0x6FD8E8))
            Spacer().frame(width: 11)
            VStack(alignment: .leading, spacing: 1) {
                Text(video != nil ? "Watch the walkthrough" : "Site visits open")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(video ?? "Ask me for a walkthrough video and floor plans")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let qr { qrBadge(qr, size: 44); Spacer().frame(width: 8) }
            dealioMark(onDark: true)
        }
        .padding(.horizontal, 18)
        // The QR is taller than the icon beside it, so the band trades padding for
        // it rather than growing — the web poster's footer is a fixed height and
        // the two are meant to print the same picture.
        .padding(.vertical, qr != nil ? 6 : 13)
        .background(LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid],
                                   startPoint: .leading, endPoint: .trailing))
    }

    /// Co-branded footer — who to call. The whole point of the template.
    private var contactBand: some View {
        let name = profile?.fullName?.nilIfEmpty ?? "Your channel partner"
        let phone = profile?.phone?.nilIfEmpty
        let rera = profile?.cp?.reraNumber?.nilIfEmpty
        let tier = profile?.cp?.tier.nilIfEmpty

        return HStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.brandTeal)
                Text(Fmt.initials(name))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)

            Spacer().frame(width: 12)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let tier {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: 0xF5C244))
                            Text(tier).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.white.opacity(0.14), in: Capsule())
                    }
                }
                if let phone {
                    Text(phone)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x9FD3E0))
                }
                if let rera {
                    Text("RERA \(rera)")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let qr { qrBadge(qr, size: 50); Spacer().frame(width: 8) }
            dealioMark(onDark: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, qr != nil ? 11 : 13)
        .background(LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid],
                                   startPoint: .leading, endPoint: .trailing))
    }

    /// Clean footer — the RERA line and nothing that ties the flyer to anyone.
    private var cleanFooter: some View {
        HStack {
            Text(project.reraNumber?.nilIfEmpty.map { "RERA \($0)" } ?? "Details on request")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.dealioTextSecondary)
                .lineLimit(1)
            Spacer()
            dealioMark(onDark: false)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color(hex: 0xF6F9FB))
    }

    /// A QR on white. The white plate is the scanner's quiet zone — the encoder is
    /// asked for a 1-module margin, under the 4 a reader wants, so the rest comes
    /// from this padding; without it most readers refuse the code.
    private func qrBadge(_ image: UIImage, size: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .padding(3)
            .frame(width: size, height: size)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func dealioMark(onDark: Bool) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.brandTeal)
                .frame(width: 6, height: 6)
            Text("Dealio")
                .font(.system(size: 10, weight: .bold)).tracking(0.5)
                .foregroundStyle(onDark ? Color.white.opacity(0.75) : Color.dealioTextSecondary)
        }
    }
}

private extension Collection {
    /// Nil for an empty collection, so `if let` reads as "there is something to draw".
    var nilIfEmptyList: Self? { isEmpty ? nil : self }
}

// MARK: - Rendering and sharing

enum FlyerRenderer {
    /// Renders the poster to a JPEG on disk at exactly 1080×1350.
    ///
    /// `ImageRenderer` runs synchronously on the main actor, which is what makes
    /// this deterministic: whatever is in the view when it is called is what lands
    /// in the file. Everything asynchronous — the hero photo, the QR — is
    /// therefore resolved before the poster is built, never inside it.
    @MainActor
    static func export(_ poster: FlyerPoster, fileName: String) -> URL? {
        let renderer = ImageRenderer(content: poster)
        renderer.scale = FlyerSize.scale
        renderer.isOpaque = true
        guard let image = renderer.uiImage,
              let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch { return nil }
    }

    /// Downloads the project's hero photograph so the poster can be rendered with
    /// it in place rather than around it.
    static func loadHero(_ project: Project) async -> UIImage? {
        guard let url = AppConfig.resolveAssetURL(project.imageUrl ?? project.coverUrl) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    /// Decodes the backend's QR data URL. Already in memory, so there is nothing
    /// to wait for — which is the point: a QR still loading when the renderer runs
    /// would be baked in as a blank square.
    static func decodeQR(_ dataURL: String?) -> UIImage? {
        guard let dataURL,
              let range = dataURL.range(of: "base64,") else { return nil }
        let payload = String(dataURL[range.upperBound...])
        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
}
