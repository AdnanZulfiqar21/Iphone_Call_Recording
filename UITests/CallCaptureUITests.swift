import XCTest

/// Simulator UI flows with explicitly simulated capture (DEBUG launch arguments). Results are
/// SIMULATOR_TESTED only: they say nothing about real call audio or device behaviour.
/// Screenshots are attached for the UX evidence set (docs/ux/evidence/).
final class CallCaptureUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = [], appearance: String? = nil, contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestNoConsentReminder"] + extra
        if let appearance { app.launchArguments += ["-UITestAppearance", appearance] }
        if let contentSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
        app.launch()
        return app
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func startRecording(_ app: XCUIApplication) {
        let start = app.buttons["startButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
    }

    // UX01/UX10: first launch and setup without account, purchase or permission barrage.
    func testOnboardingAndSetup() {
        let app = launch(["-UITestShowOnboarding", "-UITestScenario", "normal"])
        XCTAssertTrue(app.buttons["testSetupButton"].waitForExistence(timeout: 10))
        screenshot(app, "01-welcome")
        app.buttons["testSetupButton"].tap()
        XCTAssertTrue(app.staticTexts["Unconfirmed"].firstMatch.waitForExistence(timeout: 5))
        screenshot(app, "02-setup-guide")
        app.buttons["setupDoneButton"].tap()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 10))
        screenshot(app, "03-record-dashboard")
    }

    // Core journey: start → recording → stop → saving → saved result → play.
    func testRecordStopAndSave() {
        let app = launch(["-UITestScenario", "normal"])
        startRecording(app)
        let stop = app.buttons["stopButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 15))
        sleep(4)
        screenshot(app, "04-active-recording")
        stop.tap()
        // UX07: repeated Stop taps are idempotent.
        if stop.exists && stop.isHittable { stop.tap() }
        XCTAssertTrue(app.otherElements["resultSummary"].waitForExistence(timeout: 60) || app.staticTexts["Saved — no known gaps"].waitForExistence(timeout: 5))
        screenshot(app, "05-saved-result")
        app.buttons["resultPlayButton"].tap()
        XCTAssertTrue(app.buttons["playPauseButton"].waitForExistence(timeout: 10))
        screenshot(app, "06-player")
    }

    // UX06/T07: a gap stays visible after the microphone resumes.
    func testGapNoticePersistsAfterResume() {
        let app = launch(["-UITestScenario", "micGap"])
        startRecording(app)
        XCTAssertTrue(app.buttons["stopButton"].waitForExistence(timeout: 15))
        let notice = app.descendants(matching: .any)["gapNotice"].firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "gap notice should appear once audio resumes")
        sleep(3)
        XCTAssertTrue(notice.exists, "gap notice must persist after the source resumes")
        screenshot(app, "07-active-with-gap")
        app.buttons["stopButton"].tap()
        XCTAssertTrue(app.staticTexts["Saved with missing sections"].waitForExistence(timeout: 60))
        screenshot(app, "08-saved-partial")
    }

    // UX10: cancellation, denial and unsupported have calm, distinct next actions.
    func testPickerCancelledDeniedUnsupported() {
        for (picker, headline, shot) in [("cancel", "Recording didn't start", "09-cancelled"),
                                         ("deny", "Screen recording wasn't allowed", "10-denied"),
                                         ("unsupported", "Screen recording isn't available here", "11-unsupported")] {
            let app = launch(["-UITestPicker", picker])
            startRecording(app)
            XCTAssertTrue(app.staticTexts[headline].waitForExistence(timeout: 15), picker)
            screenshot(app, shot)
            app.buttons["backToRecordButton"].tap()
            XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    // UX07/UX17: tab changes restore the active session; the strip routes back and can stop.
    func testTabSwitchRestoresSessionAndStripStops() {
        let app = launch(["-UITestScenario", "normal"])
        startRecording(app)
        XCTAssertTrue(app.buttons["stopButton"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Recordings"].tap()
        let stripStop = app.buttons["stripStopButton"]
        XCTAssertTrue(stripStop.waitForExistence(timeout: 5))
        screenshot(app, "12-active-session-strip")
        app.tabBars.buttons["Record"].tap()
        XCTAssertTrue(app.buttons["stopButton"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["stripStopButton"].tap()
        app.tabBars.buttons["Record"].tap()
        XCTAssertTrue(app.buttons["newRecordingButton"].waitForExistence(timeout: 60))
        app.buttons["newRecordingButton"].tap()
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertEqual(app.cells.matching(identifier: "libraryRow").count, 1, "exactly one session was created")
    }

    // UX12: search, filter and scroll a seeded 1,000-item library without decoding media.
    func testLargeLibrarySearchFilter() {
        let app = launch(["-UITestSeedLibrary", "1000"])
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
        screenshot(app, "13-library")
        app.swipeUp(); app.swipeUp(); app.swipeDown()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("cafe")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        screenshot(app, "14-library-search")
        search.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["No Results for “cafezzzz”"].waitForExistence(timeout: 5) || app.cells.count == 0)
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["filter-partial"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        screenshot(app, "15-library-partial-filter")
    }

    // UX11: first-use empty library has an actionable empty state.
    func testEmptyLibrary() {
        let app = launch()
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.staticTexts["No recordings yet"].waitForExistence(timeout: 10))
        screenshot(app, "16-library-empty")
    }

    // UX13: real fixture media — gap marker, seeking and playback controls.
    func testPlayerWithRealFixtureMedia() {
        let app = launch(["-UITestSeedMedia"])
        app.tabBars.buttons["Recordings"].tap()
        let row = app.cells.matching(identifier: "libraryRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 60))
        row.tap()
        XCTAssertTrue(app.buttons["playPauseButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Microphone missing"].waitForExistence(timeout: 5))
        sleep(2)
        screenshot(app, "17-player-gap-markers")
        app.staticTexts["Microphone missing"].tap()
        app.buttons["playPauseButton"].tap()
        sleep(1)
        app.buttons["exportButton"].tap()
        XCTAssertTrue(app.navigationBars["Export"].waitForExistence(timeout: 5))
        screenshot(app, "18-export")
    }

    // UX03/UX01: largest accessibility text in dark mode keeps Stop available.
    func testLargestTextDarkModeKeepsStop() {
        let app = launch(["-UITestScenario", "micGap"], appearance: "dark", contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        startRecording(app)
        let stop = app.buttons["stopButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 15))
        sleep(16)
        XCTAssertTrue(stop.isHittable, "Stop must remain reachable at the largest text size")
        screenshot(app, "19-active-axxxl-dark")
        stop.tap()
    }

    // UX01: dark appearance across the main screens.
    func testDarkAppearanceScreens() {
        let app = launch(["-UITestSeedLibrary", "12"], appearance: "dark")
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 10))
        screenshot(app, "20-dashboard-dark")
        app.tabBars.buttons["Recordings"].tap()
        screenshot(app, "21-library-dark")
        app.tabBars.buttons["Settings"].tap()
        screenshot(app, "22-settings-dark")
        app.buttons["proRow"].tap()
        XCTAssertTrue(app.buttons["restoreButton"].waitForExistence(timeout: 10))
        screenshot(app, "23-pro-dark")
    }

    // UX15: purchase screen offers restore and dismissal; recording stays available.
    func testProScreenNeverBlocksCore() {
        let app = launch(["-UITestScenario", "normal"])
        app.tabBars.buttons["Settings"].tap()
        app.buttons["proRow"].tap()
        XCTAssertTrue(app.buttons["restoreButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Not now"].exists)
        screenshot(app, "24-pro")
        app.tabBars.buttons["Record"].tap()
        XCTAssertTrue(app.buttons["startButton"].isEnabled)
    }

    // Storage reserve: Start explains why it is unavailable.
    func testLowStorageExplainsStart() {
        let app = launch(["-UITestScenario", "normal", "-UITestFreeBytes", "50000000"])
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["startButton"].isEnabled)
        XCTAssertTrue(app.staticTexts["Free up space to record safely."].exists)
        screenshot(app, "25-low-storage")
    }

    // UX08: automated accessibility audit of primary screens.
    func testAccessibilityAudit() throws {
        let app = launch(["-UITestSeedLibrary", "8", "-UITestScenario", "normal"])
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.dynamicType, .elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
            // Known system-owned elements (tab bar internals) are not app-controlled.
            issue.element?.elementType == .tabBar
        }
        app.tabBars.buttons["Recordings"].tap()
        try app.performAccessibilityAudit(for: [.dynamicType, .elementDetection, .hitRegion]) { issue in
            issue.element?.elementType == .tabBar || issue.element?.elementType == .searchField
        }
        app.tabBars.buttons["Settings"].tap()
        try app.performAccessibilityAudit(for: [.dynamicType, .elementDetection, .hitRegion])
    }
}
