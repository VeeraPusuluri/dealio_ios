import SwiftUI

/// Where a portal is, and where a tap is sending it.
///
/// Each of the five tabs keeps its own navigation stack, so switching tabs
/// leaves the other four where they were. A deep link switches to the tab the
/// link belongs to and then pushes onto that tab's stack — which is what makes a
/// notification land on the screen it is about rather than on the home tab.
@MainActor
final class PortalRouter: ObservableObject {
    @Published var selection = 0
    /// One stack per tab. `NavigationPath` rather than `[PortalRoute]` because a
    /// screen pushes whatever value it has in hand — a `Project` from a list, a
    /// `PortalRoute` from a notification. A homogeneous `[PortalRoute]` binding
    /// silently *disables* every `NavigationLink(value:)` carrying any other
    /// type, which is why tapping a project used to do nothing.
    @Published var paths: [NavigationPath]

    let portal: DeepLinkPortal

    init(portal: DeepLinkPortal, tabs: Int = 5) {
        self.portal = portal
        self.paths = Array(repeating: NavigationPath(), count: tabs)
    }

    func path(_ tab: Int) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in self?.paths[safe: tab] ?? NavigationPath() },
            set: { [weak self] value in
                guard let self, self.paths.indices.contains(tab) else { return }
                self.paths[tab] = value
            }
        )
    }

    /// Follows a resolved route.
    ///
    /// A tab is entered without restoring what was stacked over it last time: a
    /// tap on "your home is booked" that restored the old stack left the user
    /// staring at the same notification list they had tapped from. A notification
    /// names one screen and has to land on it.
    func open(_ route: PortalRoute) {
        switch route {
        case .tab(let index):
            guard paths.indices.contains(index) else { return }
            selection = index
            paths[index] = NavigationPath()
        default:
            guard paths.indices.contains(selection) else { return }
            paths[selection].append(route)
        }
    }

    /// Claims whatever notification tap is waiting and follows it. Placed in each
    /// portal shell, so a tap that arrived before sign-in — or before the shell
    /// existed — is honoured the moment there is somewhere to send it.
    func follow(_ center: DeepLinkCenter) {
        guard let route = center.claim(for: portal) else { return }
        open(route)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Where a route leads

/// The one place a `PortalRoute` becomes a screen. Attach it once per navigation
/// stack with `.portalDestinations()`.
struct PortalRouteDestination: View {
    let route: PortalRoute

    var body: some View {
        switch route {
        case .tab:
            // Handled by the router before it reaches a stack.
            EmptyView()

        // Builder
        case .builderProjectDetail(let id): BuilderProjectLoader(projectId: id)
        case .builderDealDetail(let id): BuilderDealDetailView(dealId: id)
        case .builderMeetings: BuilderMeetingsView()
        case .builderUnits: BuilderInventoryView()
        case .builderCommissions: BuilderCommissionsView()
        case .builderDocuments: BuilderDocumentsView()
        case .builderLoans: BuilderLoansView()
        case .builderShortlists: BuilderShortlistsView()
        case .builderSettings: BuilderSettingsView()
        case .builderNotifications: BuilderNotificationsScreen()
        case .builderConversations: BuilderConversationsView()
        case .builderProjectForm(let id): BuilderProjectFormView(projectId: id)
        case .builderProjectDocuments(let id): BuilderProjectDocumentsLoader(projectId: id)
        case .builderRERA: BuilderRERAView()
        case .builderVirtualTours: BuilderVirtualToursView()
        case .builderBroadcast: BuilderBroadcastView()
        case .builderDemandLetters: BuilderDemandLettersView()
        case .builderAnalytics: BuilderAnalyticsView()
        case .builderAI: BuilderAIView()
        case .builderCPPerformance: BuilderCPPerformanceView()
        case .builderPossession: BuilderPossessionView()
        case .builderSnagging: BuilderSnaggingView()

        // CP
        case .cpDealDetail(let id): CPDealDetailView(dealId: id)
        case .cpProjectDetail(let id): CPProjectLoader(projectId: id)
        case .cpMeetings: CPMeetingsView()
        case .cpMeetups: CPMeetupsView()
        case .cpMeetupDetail(let id): CPMeetupDetailView(meetupId: id)
        case .cpFollowUps: CPFollowUpsView()
        case .cpContacts: CPContactsView()
        case .cpReferral: CPReferralView()
        case .cpCommunity: CPCommunityView()
        case .cpProfile: CPProfileView()
        case .cpNotifications: CPNotificationsView()
        case .cpConversations: CPConversationsView()
        case .cpCallLogs: CPCallLogsView()
        case .cpLeaderboard: CPLeaderboardView()
        case .cpAIInsights: CPAIInsightsView()
        case .cpContentStudio: CPContentStudioView()
        case .cpBrochure: CPBrochureView()
        case .cpBroadcast: CPBroadcastView()
        case .cpSocialAnalytics: CPSocialAnalyticsView()
        case .cpLoanAssist: CPLoanAssistView()
        case .cpJV: CPJVView()

        // Customer
        case .customerProjectDetail(let id): CustomerProjectLoader(projectId: id)
        case .customerDealDetail(let id): CustomerDealRoomView(dealId: id)
        case .customerProperty: CustomerPropertyView()
        case .customerLoans: CustomerLoansView()
        case .customerDocuments: CustomerDocumentsView()
        case .customerPossession: CustomerPossessionView()
        case .customerSnagging: CustomerSnaggingView()
        case .customerMeetups: CustomerMeetupsView()
        case .customerMeetupDetail(let id): CustomerMeetupDetailView(meetupId: id)
        case .customerNotifications: CustomerNotificationsView()
        case .customerConversations: CustomerConversationsView()
        case .customerEMI: CustomerEMIView()
        case .customerEligibility: CustomerLoanEligibilityView()
        case .customerLoanApply(let projectId, let builderId):
            CustomerLoanApplyView(projectId: projectId, builderId: builderId)

        // Shared
        case .conversation(let id):
            ConversationRouteView(conversationId: id)
        }
    }
}

extension View {
    /// Teaches a navigation stack every route it can be asked to push.
    ///
    /// Every one of these is declared here, on the **stack root**, rather than on
    /// the screen that pushes it. Two reasons, both learned the hard way:
    ///
    /// - A `navigationDestination(for:)` declared on a view that has itself been
    ///   pushed is not reliably matched when the stack is driven by a `path`
    ///   binding — which is why tapping a commission row opened nothing.
    /// - `navigationDestination(isPresented:)` does not work at all in a
    ///   path-driven stack, which is what the stage-action buttons on the deal
    ///   screens used to use.
    ///
    /// `Commission` and `CPStat` ride along as their own value types because the
    /// rows carrying them already hold the whole row — refetching it by id to
    /// push it would be a round trip for data the screen has in hand.
    func portalDestinations() -> some View {
        self
            .navigationDestination(for: PortalRoute.self) { PortalRouteDestination(route: $0) }
            .navigationDestination(for: Commission.self) { BuilderCommissionDetailView(commission: $0) }
            .navigationDestination(for: CPStat.self) { BuilderCPDetailView(stat: $0) }
    }
}

/// A thread opened by id, with the viewer read from the session — a link never
/// says which portal it landed in, and the bubbles need to know.
private struct ConversationRouteView: View {
    let conversationId: Int
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        ConversationThreadView(conversationId: conversationId,
                               viewer: DealRole.from(authRole: auth.role))
    }
}

// MARK: - Loading a page a link named only by id

/// A link carries an id; the detail pages take the row. These fetch it, so a
/// notification about a project opens the project rather than a dead end.
private struct BuilderProjectLoader: View {
    let projectId: Int
    @EnvironmentObject private var auth: AuthStore
    @State private var project: Project?
    @State private var failed = false

    var body: some View {
        ProjectLoadingShell(project: project, failed: failed) { ProjectDetailView(project: $0) }
            .task {
                guard let builderId = await auth.resolvedBuilderId() else { failed = true; return }
                project = try? await APIClient.shared.get("/builder/\(builderId)/projects/\(projectId)")
                failed = project == nil
            }
    }
}

private struct CPProjectLoader: View {
    let projectId: Int
    @State private var project: Project?
    @State private var failed = false

    var body: some View {
        ProjectLoadingShell(project: project, failed: failed) {
            CustomerProjectDetailView(project: $0, viewer: .cp)
        }
        .task {
            project = try? await CPService.project(projectId)
            failed = project == nil
        }
    }
}

/// The documents screen takes the whole project; a route carries only its id.
private struct BuilderProjectDocumentsLoader: View {
    let projectId: Int
    @EnvironmentObject private var auth: AuthStore
    @State private var project: Project?
    @State private var failed = false

    var body: some View {
        ProjectLoadingShell(project: project, failed: failed) {
            BuilderProjectDocumentsView(project: $0)
        }
        .task {
            guard let builderId = await auth.resolvedBuilderId() else { failed = true; return }
            project = try? await APIClient.shared.get("/builder/\(builderId)/projects/\(projectId)")
            failed = project == nil
        }
    }
}

private struct CustomerProjectLoader: View {
    let projectId: Int
    @State private var project: Project?
    @State private var failed = false

    var body: some View {
        ProjectLoadingShell(project: project, failed: failed) {
            CustomerProjectDetailView(project: $0)
        }
        .task {
            project = try? await CustomerService.project(projectId)
            failed = project == nil
        }
    }
}

private struct ProjectLoadingShell<Content: View>: View {
    let project: Project?
    let failed: Bool
    @ViewBuilder let content: (Project) -> Content

    var body: some View {
        Group {
            if let project {
                content(project)
            } else if failed {
                ContentUnavailableView("Couldn't open that project", systemImage: "building.2",
                    description: Text("It may have been unpublished since the notification was sent."))
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
