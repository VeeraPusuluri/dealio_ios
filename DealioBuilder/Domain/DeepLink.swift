import SwiftUI

/// Turning a notification into the screen it is about.
///
/// Every notification the backend persists carries a `link`: the web app's path
/// for the thing that happened — "/builder/deals/12", "/cp/leads",
/// "/customer/journey". The FCM push repeats that string in its data payload, so
/// the tray entry and the in-app bell list describe the same destination in the
/// same words. This file is the single place those words are read and answered
/// with an iOS route, which is why the two entry points can never disagree.
///
/// Links reach us in three shapes and all three are handled: a bare section
/// ("/cp/leads"), an id in the path ("/customer/deals/12"), and an id as a query
/// hint ("/builder/deals?dealId=12"). Mirrors Android's `ui/navigation/DeepLink.kt`.

enum DeepLinkPortal: String {
    case builder, cp, customer

    var segment: String { rawValue }

    /// Where this portal's own notification endpoints live.
    var endpointPrefix: String { "/" + rawValue }

    static func forAuthRole(_ role: String?) -> DeepLinkPortal {
        switch (role ?? "").uppercased() {
        case "BUILDER": return .builder
        case "CP": return .cp
        default: return .customer
        }
    }
}

/// A destination inside a portal. `tab` switches the pill nav; everything else
/// is pushed onto the current stack so Back returns where the tap came from.
enum PortalRoute: Hashable {
    case tab(Int)

    // Builder
    case builderProjectDetail(Int)
    case builderDealDetail(Int)
    case builderMeetings
    case builderUnits
    case builderCommissions
    case builderDocuments
    case builderLoans
    case builderShortlists
    case builderSettings
    case builderNotifications
    case builderConversations
    /// The project wizard. `nil` creates; an id edits.
    case builderProjectForm(Int?)
    case builderProjectDocuments(Int)
    case builderRERA
    case builderVirtualTours
    case builderBroadcast
    case builderDemandLetters
    case builderAnalytics
    case builderAI
    case builderCPPerformance
    case builderPossession
    case builderSnagging

    // CP
    case cpDealDetail(Int)
    case cpProjectDetail(Int)
    case cpMeetings
    case cpMeetups
    case cpMeetupDetail(Int)
    case cpFollowUps
    case cpContacts
    case cpReferral
    case cpCommunity
    case cpProfile
    case cpNotifications
    case cpConversations
    case cpCallLogs
    case cpLeaderboard
    case cpAIInsights
    case cpContentStudio
    case cpBrochure
    case cpBroadcast
    case cpSocialAnalytics
    case cpLoanAssist
    case cpJV

    // Customer
    case customerProjectDetail(Int)
    case customerDealDetail(Int)
    case customerProperty
    case customerLoans
    case customerDocuments
    case customerPossession
    case customerSnagging
    case customerMeetups
    case customerMeetupDetail(Int)
    case customerNotifications
    case customerConversations
    case customerEMI
    case customerEligibility
    /// The loan application form, optionally pre-filled from a project.
    case customerLoanApply(projectId: Int?, builderId: Int?)

    // Shared
    case conversation(Int)
}

enum DeepLink {
    /// Maps a backend link to a route inside `portal`, or nil when it belongs
    /// somewhere else. A link is written for one recipient's portal, so a path
    /// under another one is not ours to follow.
    static func resolve(portal: DeepLinkPortal, link: String?) -> PortalRoute? {
        let raw = (link ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let parts = raw.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let query = parts.count > 1 ? String(parts[1]) : ""
        let segments = parts[0].split(separator: "/").map(String.init)
        guard segments.first == portal.segment else { return nil }

        let section = segments.count > 1 ? segments[1] : ""
        let pathId = segments.count > 2 ? Int(segments[2]) : nil

        switch portal {
        case .builder: return builderRoute(section, pathId, query)
        case .cp: return cpRoute(section, pathId, query)
        case .customer: return customerRoute(section, pathId, query)
        }
    }

    // A section the app doesn't have falls through to that portal's notification
    // list rather than nowhere: the alert is listed there in full, so the tap
    // still answers "what was this about?".

    private static func builderRoute(_ section: String, _ pathId: Int?, _ query: String) -> PortalRoute {
        switch section {
        case "", "home", "dashboard", "overview": return .tab(0)
        case "deals":
            if let id = pathId ?? query.intValue("dealId") { return .builderDealDetail(id) }
            return .tab(3)
        case "leads", "pipeline": return .tab(2)
        case "projects":
            if let id = pathId ?? query.intValue("projectId") { return .builderProjectDetail(id) }
            return .tab(1)
        case "conversations":
            if let id = pathId ?? query.intValue("conversationId") { return .conversation(id) }
            return .builderConversations
        case "meetings": return .builderMeetings
        case "units": return .builderUnits
        case "commissions": return .builderCommissions
        case "documents": return .builderDocuments
        case "loans": return .builderLoans
        case "shortlists": return .builderShortlists
        case "settings": return .builderSettings
        default: return .builderNotifications
        }
    }

    private static func cpRoute(_ section: String, _ pathId: Int?, _ query: String) -> PortalRoute {
        switch section {
        case "", "home", "dashboard", "overview": return .tab(0)
        // The CP portal calls its deals "leads" on the web and in the tab bar;
        // both spellings arrive, and both open the same pipeline.
        case "leads", "pipeline", "deals":
            if let id = pathId ?? query.intValue("dealId") { return .cpDealDetail(id) }
            return .tab(1)
        case "projects":
            if let id = pathId ?? query.intValue("projectId") { return .cpProjectDetail(id) }
            return .tab(2)
        case "conversations":
            if let id = pathId ?? query.intValue("conversationId") { return .conversation(id) }
            return .cpConversations
        case "earnings", "commissions": return .tab(3)
        case "meetings": return .cpMeetings
        case "meetups":
            if let id = pathId ?? query.intValue("meetupId") { return .cpMeetupDetail(id) }
            return .cpMeetups
        case "followups": return .cpFollowUps
        case "contacts": return .cpContacts
        case "referral": return .cpReferral
        case "community": return .cpCommunity
        // Verification results are the only thing sent to /cp/settings, and the
        // profile screen is where a partner's verification state lives here.
        case "settings", "profile": return .cpProfile
        default: return .cpNotifications
        }
    }

    private static func customerRoute(_ section: String, _ pathId: Int?, _ query: String) -> PortalRoute {
        switch section {
        case "", "home", "explore": return .tab(0)
        // A buyer's deal lives under the Journey tab, so a link to either — with
        // an id or without — belongs to the same pair of screens.
        case "journey", "deals":
            if let id = pathId ?? query.intValue("dealId") { return .customerDealDetail(id) }
            return .tab(2)
        case "projects", "project":
            if let id = pathId ?? query.intValue("projectId") { return .customerProjectDetail(id) }
            return .tab(0)
        case "conversations":
            if let id = pathId ?? query.intValue("conversationId") { return .conversation(id) }
            return .customerConversations
        // Site visits are "meeting" on the web and "Visits" here.
        case "meeting", "meetings", "visits": return .tab(1)
        case "property": return .customerProperty
        case "loan", "loans": return .customerLoans
        case "documents": return .customerDocuments
        case "possession": return .customerPossession
        case "snagging": return .customerSnagging
        case "meetups":
            if let id = pathId ?? query.intValue("meetupId") { return .customerMeetupDetail(id) }
            return .customerMeetups
        case "saved": return .tab(3)
        case "profile": return .tab(4)
        default: return .customerNotifications
        }
    }
}

/// Reads one numeric query value out of a raw query string ("tab=status&dealId=12").
private extension String {
    func intValue(_ key: String) -> Int? {
        split(separator: "&")
            .first { $0.split(separator: "=", maxSplits: 1).first.map(String.init) == key }
            .flatMap { $0.split(separator: "=", maxSplits: 1).last.map(String.init) }
            .flatMap(Int.init)
    }
}

// MARK: - The pending tap

/// A tap waiting for somewhere to land.
///
/// The tap can arrive long before there is anywhere to send it — on a cold start
/// the payload is read while the splash screen is still up, and if the user is
/// signed out there is no portal at all until they sign in. So the link is held
/// here until a portal shell claims it.
@MainActor
final class DeepLinkCenter: ObservableObject {
    static let shared = DeepLinkCenter()

    @Published private(set) var pending: String?

    func offer(_ link: String?) {
        guard let link, !link.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        pending = link
    }

    /// Drops any unclaimed link — on sign-out, so it can't follow the next user in.
    func clear() { pending = nil }

    /// Claims whatever tap is waiting and resolves it for `portal`. Returns nil
    /// when nothing is waiting or the link belongs to another portal; the link is
    /// consumed either way so it can't fire again on the next screen.
    func claim(for portal: DeepLinkPortal) -> PortalRoute? {
        guard let link = pending else { return nil }
        pending = nil
        return DeepLink.resolve(portal: portal, link: link)
    }
}
