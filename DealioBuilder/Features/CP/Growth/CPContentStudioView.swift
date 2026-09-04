import SwiftUI
import Photos

/// Content Studio — the two things a CP needs before posting a project: words and
/// an image.
///
/// Captions are generated three at a time, one per tone, because the right
/// caption depends on who is being posted to and that is a judgement only the CP
/// can make. Flyers render as real 1080×1350 images, and whichever caption the CP
/// picked travels with the flyer when it is shared. Mirrors Android's
/// `ui/cp/growth/ContentStudioScreen.kt`.

private struct SocialPlatform: Identifiable {
    let id: String
    let label: String
    let color: Color
}

private let socialPlatforms = [
    SocialPlatform(id: "whatsapp", label: "WhatsApp", color: Color(hex: 0x25D366)),
    SocialPlatform(id: "instagram", label: "Instagram", color: Color(hex: 0xE4405F)),
    SocialPlatform(id: "facebook", label: "Facebook", color: Color(hex: 0x1877F2)),
    SocialPlatform(id: "linkedin", label: "LinkedIn", color: Color(hex: 0x0A66C2)),
]

private enum StudioMode: String, CaseIterable { case caption = "Captions", flyer = "Flyer" }

struct CPContentStudioView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CPGrowthModel()

    @State private var selectedProjectId: Int?
    @State private var mode: StudioMode = .caption

    // Caption state
    @State private var offerId: String?
    @State private var platform = "whatsapp"
    @State private var variants: [CaptionVariant] = []
    @State private var chosenTone: String?
    @State private var draft = ""
    @State private var seed = 0

    // Flyer state
    @State private var template: FlyerTemplate = .showcase
    @State private var hero: UIImage?
    @State private var heroSettled = false
    @State private var exporting = false
    @State private var sharing: FlyerShare?
    @State private var message: String?

    private var selected: Project? { model.projects.first { $0.id == selectedProjectId } }
    private var offer: OfferType? { offerTypeOf(offerId) }

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        projectPicker

                        if selected == nil {
                            Text("Pick a project to write captions and build a flyer for it.")
                                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                                .padding(.horizontal, 4)
                        } else {
                            modeTabs
                            if mode == .caption { captionFlow } else { flyerFlow }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Content Studio")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
        // Only once the flyer tab is actually open: the QR is drawn on the poster
        // and nowhere else, so a CP writing captions never pays for the call.
        .task(id: FlyerContext(projectId: selectedProjectId, mode: mode)) {
            guard mode == .flyer, let id = selectedProjectId else { return }
            await model.loadShareQR(projectId: id)
            if let project = selected {
                hero = await FlyerRenderer.loadHero(project)
                heroSettled = true
            }
        }
        .sheet(item: $sharing) { share in
            ActivityShareSheet(items: share.items)
        }
        .alert("Content Studio", isPresented: Binding(get: { message != nil },
                                                      set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    /// Both halves of "which QR do we need" in one value, so the task restarts
    /// when either changes.
    private struct FlyerContext: Equatable { let projectId: Int?; let mode: StudioMode }

    private func resetCaptions() {
        variants = []
        chosenTone = nil
        draft = ""
        seed = 0
    }

    // MARK: 1. Project

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("1. Pick a project")
            if model.projects.isEmpty {
                Text("No projects yet. They appear here once builders publish them.")
                    .font(.caption).foregroundStyle(Color.dealioTextSecondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.projects) { project in
                            let on = project.id == selectedProjectId
                            Button {
                                selectedProjectId = project.id
                                resetCaptions()
                                hero = nil
                                heroSettled = false
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(project.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.dealioTextPrimary)
                                    Text([project.builderName ?? "—", project.city ?? ""]
                                            .filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(on ? Color(hex: 0xEAFAFC) : Color(.secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(on ? Color.brandTeal : Color.dealioCardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var modeTabs: some View {
        HStack(spacing: 4) {
            ForEach(StudioMode.allCases, id: \.self) { option in
                let on = mode == option
                Button { withAnimation(.snappy) { mode = option } } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(on ? .bold : .medium))
                        .foregroundStyle(on ? Color.brandTeal : Color.dealioTextSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(on ? Color(.secondarySystemGroupedBackground) : .clear,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: 0xEDF1F7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Captions

    @ViewBuilder
    private var captionFlow: some View {
        offerPicker

        if offer == nil {
            Text("Pick an offer type and the captions will be written around its terms.")
                .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                .padding(.horizontal, 4)
        } else {
            platformPicker
            generateButton
            if !variants.isEmpty { variantList }
            if chosenTone != nil { editAndSend }
        }
    }

    private var offerPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("2. What is on offer?")
                Text("The caption is built around this, so pick the one you are actually selling on.")
                    .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(offerTypes) { option in
                        let on = offerId == option.id
                        Button { offerId = option.id; resetCaptions() } label: {
                            HStack(spacing: 10) {
                                Text(option.emoji).font(.system(size: 15))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(on ? Color.brandTeal : Color.dealioTextPrimary)
                                    Text(option.keyFeature)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(Color.dealioTextSecondary)
                                }
                                Spacer(minLength: 8)
                                if on {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(Color.brandTeal)
                                }
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(on ? Color(hex: 0xF3FCFD) : Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(on ? Color.brandTeal : Color.dealioCardBorder,
                                                  lineWidth: on ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var platformPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("3. Choose platform")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(socialPlatforms) { option in
                        let on = platform == option.id
                        Button { platform = option.id; resetCaptions() } label: {
                            Text(option.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(on ? .white : Color.dealioTextSecondary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(on ? option.color : Color(.secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(on ? option.color : Color.dealioCardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var generateButton: some View {
        Button {
            // `captionVariants` is a pure function — there is nothing to wait for.
            guard let project = selected, let offer else { return }
            let next = variants.isEmpty ? 0 : seed + 1
            seed = next
            variants = captionVariants(project: project, offer: offer, platform: platform, seed: next)
            chosenTone = nil
            draft = ""
        } label: {
            Label(variants.isEmpty ? "Write 3 captions" : "Write 3 more",
                  systemImage: variants.isEmpty ? "sparkles" : "arrow.clockwise")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var variantList: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("4. Pick the one that fits")
                Text("Same offer, three angles. Tap one to edit and send it.")
                    .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }
            ForEach(variants) { variant in
                let on = chosenTone == variant.tone.id
                Button { chosenTone = variant.tone.id; draft = variant.text } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(variant.tone.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(on ? Color.brandTeal : Color.dealioTextPrimary)
                            Spacer()
                            if on {
                                Image(systemName: "checkmark.circle").foregroundStyle(Color.brandTeal)
                            } else {
                                Text("Use this").font(.caption2.weight(.semibold)).foregroundStyle(Color.brandTeal)
                            }
                        }
                        Text(variant.tone.blurb)
                            .font(.system(size: 10)).foregroundStyle(Color.dealioTextSecondary)
                        Text(variant.text)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.dealioTextSecondary)
                            .lineLimit(on ? nil : 5)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(on ? Color(hex: 0xF3FCFD) : Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(on ? Color.brandTeal : Color.dealioCardBorder, lineWidth: on ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var editAndSend: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("5. Edit and send")
                Spacer()
                Button {
                    Share.copy(draft)
                    message = "Caption copied"
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.brandTeal)
                }
                .buttonStyle(.plain)
            }
            TextEditor(text: $draft)
                .font(.system(size: 13))
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.dealioFieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
                )
            HStack(spacing: 10) {
                Button {
                    if platform == "whatsapp" {
                        if let url = Share.whatsAppURL(phone: nil, text: draft) { openURL(url) }
                    } else {
                        sharing = FlyerShare(items: [draft])
                    }
                } label: {
                    Text(platform == "whatsapp" ? "Send on WhatsApp" : "Share")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(platform == "whatsapp" ? Color(hex: 0x25D366) : Color.brandTeal,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { withAnimation(.snappy) { mode = .flyer } } label: {
                    Text("Add a flyer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dealioTextSecondary)
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .background(Color(hex: 0xEDF1F7),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    // MARK: Flyer

    @ViewBuilder
    private var flyerFlow: some View {
        if let project = selected {
            templatePicker(project)
            preview(project)
            flyerActions(project)
        }
    }

    private func templatePicker(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("2. Choose a template")
            ForEach(FlyerTemplate.allCases) { option in
                let on = template == option
                Button { template = option } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(on ? Color.brandTeal : Color.dealioTextPrimary)
                            Text(option.blurb)
                                .font(.system(size: 10.5)).foregroundStyle(Color.dealioTextSecondary)
                        }
                        Spacer(minLength: 8)
                        if on { Image(systemName: "checkmark.circle").foregroundStyle(Color.brandTeal) }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(on ? Color(hex: 0xF3FCFD) : Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(on ? Color.brandTeal : Color.dealioCardBorder, lineWidth: on ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
            if template == .showcase, project.videoUrl?.nilIfEmpty == nil {
                Text("This project has no walkthrough video yet, so the footer invites the buyer to ask for one.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func preview(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("3. Preview")
            GeometryReader { geo in
                let scale = geo.size.width / FlyerSize.width
                poster(project)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: geo.size.width, height: FlyerSize.height * scale)
            }
            .frame(height: FlyerSize.height * ((UIScreen.main.bounds.width - 88) / FlyerSize.width))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Shares as a 1080 × 1350 image"
                 + (draft.trimmedOrNil != nil ? ", with your caption attached." : "."))
                .font(.system(size: 10.5))
                .foregroundStyle(Color.dealioTextSecondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func poster(_ project: Project) -> FlyerPoster {
        FlyerPoster(
            template: template, project: project, profile: model.profile,
            hero: hero,
            qr: FlyerRenderer.decodeQR(model.shareQR[project.id] ?? nil)
        )
    }

    private func flyerActions(_ project: Project) -> some View {
        // The QR is part of the poster, so exporting before the share-link call
        // settles would bake a flyer with a hole where the tracked link belongs.
        let heroURL = AppConfig.resolveAssetURL(project.imageUrl ?? project.coverUrl)
        let ready = (heroSettled || heroURL == nil) && model.shareQRSettled(project.id)

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                flyerAction(exporting ? "Preparing…" : "WhatsApp", Color(hex: 0x25D366), enabled: ready) {
                    // WhatsApp cannot take an image and text in one URL, so the
                    // system sheet is the honest route: it hands both across in
                    // whichever app the CP picks.
                    withFlyer(project) { url in sharing = FlyerShare(items: shareItems(url)) }
                }
                flyerAction("Share", .brandTeal, icon: "square.and.arrow.up", enabled: ready) {
                    withFlyer(project) { url in sharing = FlyerShare(items: shareItems(url)) }
                }
                flyerAction("Save", Color(hex: 0xEDF1F7), textColor: .dealioTextSecondary,
                            icon: "arrow.down.to.line", enabled: ready) {
                    withFlyer(project) { url in save(url) }
                }
            }
            if !ready {
                Text("Preparing the poster — the photo and your tracked link are still loading.")
                    .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }
        }
    }

    private func shareItems(_ url: URL) -> [Any] {
        var items: [Any] = [url]
        if let caption = draft.trimmedOrNil { items.append(caption) }
        return items
    }

    private func flyerAction(_ title: String, _ fill: Color, textColor: Color = .white,
                             icon: String? = nil, enabled: Bool,
                             _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon { Label(title, systemImage: icon) } else { Text(title) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(enabled && !exporting ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || exporting)
    }

    /// Renders once, then hands the file to `then`. Shared by all three actions.
    private func withFlyer(_ project: Project, then: @escaping (URL) -> Void) {
        guard !exporting else { return }
        exporting = true
        let fileName = "flyer-\(project.id)-\(template.rawValue).jpg"
        if let url = FlyerRenderer.export(poster(project), fileName: fileName) {
            then(url)
        } else {
            message = "Could not build the flyer"
        }
        exporting = false
    }

    /// Saves into the photo library. Add-only access is enough, and it is the
    /// narrower prompt of the two, so that is what is asked for.
    private func save(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in message = "Allow photo access to save flyers, or use Share." }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            } completionHandler: { ok, _ in
                Task { @MainActor in message = ok ? "Saved to Photos" : "Could not save the flyer" }
            }
        }
    }
}

/// A share payload for `.sheet(item:)` — a file plus, optionally, the caption.
struct FlyerShare: Identifiable {
    let items: [Any]
    let id = UUID()
}
