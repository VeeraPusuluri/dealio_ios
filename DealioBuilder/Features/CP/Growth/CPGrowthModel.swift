import Foundation

/// One model behind every growth screen.
///
/// Each screen reads the slice it needs; loads are best-effort so a single
/// failing endpoint doesn't blank the whole screen. Mirrors Android's
/// `ui/cp/growth/CpGrowth.kt`.
@MainActor
final class CPGrowthModel: ObservableObject {
    @Published var loading = true
    @Published var error: String?
    @Published var leads: [CpLead] = []
    @Published var profile: CpProfile?
    @Published var contacts: [CpContact] = []
    @Published var projects: [Project] = []

    /// Share-link QR per project id, as a PNG data URL, populated on demand.
    ///
    /// A present key means the fetch settled; a nil value means it settled with
    /// no QR. The flyer's export button waits on the *key*, so the two cases have
    /// to be distinguishable — collapsing them would leave the button disabled
    /// forever whenever the server could not encode a code.
    @Published var shareQR: [Int: String?] = [:]

    private var cpUserId = 0

    func load(cpUserId: Int) async {
        self.cpUserId = cpUserId
        loading = projects.isEmpty && leads.isEmpty
        error = nil
        leads = (try? await CPService.leads(cpUserId: cpUserId)) ?? leads
        profile = (try? await CPService.profile(cpUserId: cpUserId)) ?? profile
        contacts = (try? await CPService.contacts(cpUserId: cpUserId)) ?? contacts
        projects = (try? await CPService.projects()) ?? projects
        loading = false
    }

    /// Fetches (and mints, server-side) the CP's tracked share link for a project
    /// and keeps its QR.
    ///
    /// On demand rather than in `load`: the QR is only drawn on the flyer, so a CP
    /// who never opens the flyer tab never pays for a call per project. Cached by
    /// id because the token is stable — flipping between projects must not
    /// re-mint anything.
    func loadShareQR(projectId: Int) async {
        guard shareQR.index(forKey: projectId) == nil else { return }
        let link = try? await CPService.shareLink(cpUserId: cpUserId, projectId: projectId)
        shareQR[projectId] = link?.qr
    }

    /// Whether the share-link call has settled for this project, QR or not.
    func shareQRSettled(_ projectId: Int) -> Bool { shareQR.index(forKey: projectId) != nil }
}
