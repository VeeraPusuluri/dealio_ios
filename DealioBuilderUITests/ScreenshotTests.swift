import XCTest

/// Walks to each redesigned screen and attaches a screenshot.
///
/// Not an assertion suite — it exists so the pushed screens (which cannot be
/// reached with `simctl` alone) can be eyeballed for clipping, contrast and
/// safe-area problems in both appearances. Run it and pull the attachments out
/// of the `.xcresult`.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    private func launch(role: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-role", role]
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Waits for the tab before tapping it. On a physical device the shell is
    /// not always laid out by the time `launch()` returns, and a bare tap on a
    /// not-yet-existing tab silently does nothing.
    private func tapTab(_ app: XCUIApplication, _ label: String) {
        let tab = app.buttons["tab.\(label)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Tab '\(label)' never appeared")
        tab.tap()
    }

    private func reveal(_ app: XCUIApplication, _ element: XCUIElement, swipes: Int = 8) {
        let scroller: XCUIElement = {
            if app.collectionViews.firstMatch.exists { return app.collectionViews.firstMatch }
            if app.tables.firstMatch.exists { return app.tables.firstMatch }
            return app.scrollViews.firstMatch
        }()
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return }
            guard scroller.exists else { return }
            scroller.swipeUp()
        }
    }

    func testCaptureCustomerProjectDetail() {
        let app = launch(role: "CUSTOMER")
        let card = app.buttons.containing(.staticText, identifier: "Lakeside Habitat").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.staticTexts["Developer"].waitForExistence(timeout: 10))
        capture(app, "customer-project-detail-top")

        // Location Advantages sits mid-page; the Developer panel closes it.
        reveal(app, app.staticTexts["Location Advantages"], swipes: 12)
        capture(app, "customer-project-detail-location")

        reveal(app, app.staticTexts["Built by"], swipes: 12)
        capture(app, "customer-project-detail-developer")
    }

    func testCaptureExploreFilterSheet() {
        let app = launch(role: "CUSTOMER")
        let filters = app.buttons["Filters and sorting"]
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
        filters.tap()
        XCTAssertTrue(app.staticTexts["Refine"].waitForExistence(timeout: 10))
        capture(app, "explore-filter-sheet")
    }

    func testCaptureContactForm() {
        let app = launch(role: "CP")
        tapTab(app, "More")
        let contacts = app.staticTexts["Contacts"]
        reveal(app, contacts)
        contacts.tap()
        let add = app.navigationBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        app.buttons["Enter one by hand"].tap()
        XCTAssertTrue(app.staticTexts["Who they are"].waitForExistence(timeout: 10))
        capture(app, "cp-contact-form")
        app.buttons["Add contact"].tap()
        XCTAssertTrue(app.staticTexts["Full name is required"].waitForExistence(timeout: 5))
        capture(app, "cp-contact-form-errors")
    }

    func testCaptureProjectForm() {
        let app = launch(role: "BUILDER")
        tapTab(app, "Projects")
        let add = app.navigationBars.buttons["New project"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.staticTexts["The project"].waitForExistence(timeout: 10))
        capture(app, "builder-project-form-top")
        app.buttons["Publish project"].tap()
        capture(app, "builder-project-form-errors")
        app.swipeUp(); app.swipeUp()
        capture(app, "builder-project-form-middle")
    }

    func testCaptureBuilderProjectDetail() {
        let app = launch(role: "BUILDER")
        tapTab(app, "Projects")
        let row = app.buttons.containing(.staticText, identifier: "Lakeside Habitat").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["Project"].waitForExistence(timeout: 10))
        capture(app, "builder-project-detail-top")

        reveal(app, app.staticTexts["Location Advantages"])
        capture(app, "builder-project-detail-location")

        // Scroll *to* the panel rather than flicking blindly past it: a blind
        // swipe landed on "Visit developer website" and opened Safari.
        reveal(app, app.staticTexts["Built by"])
        capture(app, "builder-project-detail-developer")
    }

    func testCaptureCommissionDetail() {
        let app = launch(role: "BUILDER")
        tapTab(app, "More")
        let commissions = app.staticTexts["Commissions"]
        reveal(app, commissions)
        commissions.tap()
        let row = app.buttons.containing(.staticText, identifier: "Anita Rao").firstMatch
        reveal(app, row)
        row.tap()
        XCTAssertTrue(app.staticTexts["How it was worked out"].waitForExistence(timeout: 10))
        capture(app, "builder-commission-detail")
    }

    func testCaptureCPPerformanceDetail() {
        let app = launch(role: "BUILDER")
        tapTab(app, "More")
        let performance = app.staticTexts["CP Performance"]
        reveal(app, performance)
        performance.tap()
        capture(app, "builder-cp-performance-list")
        let row = app.buttons.containing(.staticText, identifier: "Ravi Kumar").firstMatch
        reveal(app, row)
        row.tap()
        XCTAssertTrue(app.staticTexts["Conversion"].waitForExistence(timeout: 10))
        capture(app, "builder-cp-performance-detail")
    }

    func testCaptureSignupAndOtp() {
        let app = launch(role: "NONE")
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 10))
        capture(app, "login")
        app.buttons["Create an account"].tap()
        XCTAssertTrue(app.staticTexts["Create your account"].waitForExistence(timeout: 10))
        capture(app, "signup")
    }
}
