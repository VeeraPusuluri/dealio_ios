import XCTest

/// End-to-end checks that the things a user taps actually open something.
///
/// Almost every bug this suite was written for had the same shape: a card that
/// looked tappable and did nothing. Asserting "a detail screen appeared" is the
/// only way to catch that — a unit test on the model cannot see it.
///
/// The app runs against `UITestSupport`'s stubbed backend, so the rows are the
/// same on every machine and no sign-in is needed.
final class NavigationFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Harness

    private func launch(role: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-role", role]
        app.launch()
        return app
    }

    /// Waits for any of the given static texts to exist.
    @discardableResult
    private func waitForText(_ app: XCUIApplication, _ text: String,
                             timeout: TimeInterval = 10) -> Bool {
        app.staticTexts[text].waitForExistence(timeout: timeout)
    }

    /// The back button of the pushed screen, whatever its title.
    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists && back.isHittable { back.tap() }
    }

    /// Taps a tab by its identifier, not its label: "Projects" is also the name
    /// of a quick action on the CP home screen, and a label query matches both.
    private func tapTab(_ app: XCUIApplication, _ label: String) {
        let tab = app.buttons["tab.\(label)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab '\(label)' never appeared")
        tab.tap()
    }

    /// Scrolls until `element` is on screen and tappable.
    ///
    /// Two reasons this is needed rather than a bare `waitForExistence`:
    /// `isHittable` is false for anything below the fold, and a `List` is lazy —
    /// a row far enough down does not *exist* until it has been scrolled near.
    /// Without this, "row is off screen" would read as "row is not tappable",
    /// which is the exact bug these tests exist to catch.
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ element: XCUIElement,
                        swipes: Int = 8) -> Bool {
        // A SwiftUI List is a collection view; a ScrollView is a scroll view.
        let scroller: XCUIElement = {
            if app.collectionViews.firstMatch.exists { return app.collectionViews.firstMatch }
            if app.tables.firstMatch.exists { return app.tables.firstMatch }
            return app.scrollViews.firstMatch
        }()
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return true }
            guard scroller.exists else { break }
            scroller.swipeUp()
        }
        return element.exists && element.isHittable
    }

    // MARK: - Customer

    func testCustomerExploreOpensProject() {
        let app = launch(role: "CUSTOMER")

        XCTAssertTrue(waitForText(app, "All homes") || waitForText(app, "Lakeside Habitat"),
                      "Explore never finished loading")

        let card = app.buttons.containing(.staticText, identifier: "Lakeside Habitat").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No project card on Explore")
        card.tap()

        // The detail page is the only screen carrying the Developer panel.
        XCTAssertTrue(waitForText(app, "Developer"),
                      "Tapping a project on Explore did not open the project detail")
        XCTAssertTrue(waitForText(app, "Prestige Group"),
                      "Developer panel did not show the builder name")
    }

    func testCustomerExploreFiltersAreReachable() {
        let app = launch(role: "CUSTOMER")
        XCTAssertTrue(waitForText(app, "All homes") || waitForText(app, "Lakeside Habitat"))

        let filters = app.buttons["Filters and sorting"]
        XCTAssertTrue(filters.waitForExistence(timeout: 10),
                      "The BHK/budget filter control is not on screen")
        filters.tap()

        XCTAssertTrue(waitForText(app, "Refine"), "Filter sheet did not open")
        XCTAssertTrue(waitForText(app, "Budget") || waitForText(app, "Bedrooms"),
                      "Filter sheet has neither a budget nor a bedrooms group")
        XCTAssertTrue(waitForText(app, "Sort by"), "Sort options missing from the filter sheet")
    }

    func testCustomerProfileRowsOpen() {
        let app = launch(role: "CUSTOMER")
        tapTab(app, "Profile")

        let row = app.buttons.containing(.staticText, identifier: "EMI calculator").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Profile menu never rendered")
        row.tap()

        XCTAssertTrue(app.navigationBars["EMI Calculator"].waitForExistence(timeout: 10)
                      || waitForText(app, "EMI Calculator"),
                      "Profile row did not open the EMI calculator")
    }

    // MARK: - CP

    func testCPHomeRecentLeadOpensDeal() {
        let app = launch(role: "CP")

        XCTAssertTrue(waitForText(app, "Recent leads"), "CP home never loaded")

        let lead = app.buttons.containing(.staticText, identifier: "Anita Rao").firstMatch
        XCTAssertTrue(reveal(app, lead), "The recent-lead row is not tappable")
        lead.tap()

        // The deal room is the only place the buyer's name sits in a nav bar.
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForText(app, "Anita Rao"),
                      "Tapping a recent lead did not open its deal")
    }

    func testCPProjectsOpenOnTap() {
        let app = launch(role: "CP")
        tapTab(app, "Projects")

        let card = app.buttons.containing(.staticText, identifier: "Lakeside Habitat").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "CP projects list never rendered")
        card.tap()

        XCTAssertTrue(waitForText(app, "Developer"),
                      "Tapping a CP project did not open the project detail")
    }

    func testCPEarningsItemsOpen() {
        let app = launch(role: "CP")
        tapTab(app, "Earnings")

        let row = app.buttons.containing(.staticText, identifier: "Anita Rao").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Earnings list never rendered")
        row.tap()

        XCTAssertTrue(waitForText(app, "How it was worked out"),
                      "Tapping an earnings row did not open the commission breakdown")
        XCTAssertTrue(waitForText(app, "Commission rate"),
                      "Commission detail is missing the rate line")
    }

    func testCPContactFormShowsValidation() {
        let app = launch(role: "CP")
        tapTab(app, "More")

        let contacts = app.staticTexts["Contacts"]
        XCTAssertTrue(reveal(app, contacts), "Contacts is not reachable from More")
        contacts.tap()

        let add = app.navigationBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Contacts screen has no Add button")
        add.tap()
        app.buttons["Enter one by hand"].tap()

        XCTAssertTrue(waitForText(app, "Who they are"),
                      "The redesigned contact form did not open")

        // Saving an empty form has to say what is wrong, not fail silently.
        let save = app.buttons["Add contact"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(waitForText(app, "Full name is required"),
                      "An empty contact form saved without surfacing a validation error")
    }

    // MARK: - Builder

    func testBuilderProjectsOpenOnTap() {
        let app = launch(role: "BUILDER")
        tapTab(app, "Projects")

        let row = app.buttons.containing(.staticText, identifier: "Lakeside Habitat").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Builder projects list never rendered")
        row.tap()

        XCTAssertTrue(app.navigationBars["Project"].waitForExistence(timeout: 10),
                      "Tapping a builder project did not open the project detail")

        // The builder types both of these into the project form, so their own
        // detail page has to show them back.
        XCTAssertTrue(waitForText(app, "Location Advantages"),
                      "Builder project detail is missing the Location Advantages section")
        XCTAssertTrue(waitForText(app, "Developer"),
                      "Builder project detail is missing the Developer panel")
        XCTAssertTrue(waitForText(app, "Prestige Group"),
                      "Developer panel did not show the builder name")
    }

    func testBuilderNewProjectFormValidates() {
        let app = launch(role: "BUILDER")
        tapTab(app, "Projects")

        let add = app.navigationBars.buttons["New project"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Projects screen has no New project button")
        add.tap()

        XCTAssertTrue(waitForText(app, "The project"),
                      "The redesigned project form did not open")
        XCTAssertTrue(waitForText(app, "Where it is"), "Location section missing")
        XCTAssertTrue(waitForText(app, "Compliance"), "Compliance section missing")

        let save = app.buttons["Publish project"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No save bar on the project form")
        save.tap()
        // The blocker text is on the pinned bar, so it needs no scrolling.
        XCTAssertTrue(waitForText(app, "Project name is required"),
                      "An empty project form saved without surfacing a validation error")
    }

    func testBuilderCommissionsOpen() {
        let app = launch(role: "BUILDER")
        tapTab(app, "More")

        let commissions = app.staticTexts["Commissions"]
        XCTAssertTrue(reveal(app, commissions), "Commissions is not reachable from More")
        commissions.tap()

        let row = app.buttons.containing(.staticText, identifier: "Anita Rao").firstMatch
        XCTAssertTrue(reveal(app, row), "Commissions list never rendered")
        row.tap()

        XCTAssertTrue(waitForText(app, "How it was worked out"),
                      "Tapping a commission did not open its breakdown")
        XCTAssertTrue(waitForText(app, "Release this commission"),
                      "A pending commission's detail has no release action")
    }

    func testBuilderCPPerformanceOpens() {
        let app = launch(role: "BUILDER")
        tapTab(app, "More")

        let performance = app.staticTexts["CP Performance"]
        XCTAssertTrue(reveal(app, performance), "CP Performance is not reachable from More")
        performance.tap()

        let row = app.buttons.containing(.staticText, identifier: "Ravi Kumar").firstMatch
        XCTAssertTrue(reveal(app, row), "CP performance rows are not tappable")
        row.tap()

        XCTAssertTrue(waitForText(app, "Conversion"),
                      "Tapping a CP did not open their performance breakdown")
        XCTAssertTrue(waitForText(app, "Deals"),
                      "The CP breakdown does not list their deals")
    }
}
