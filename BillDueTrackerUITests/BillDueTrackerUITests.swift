import XCTest

final class BillDueTrackerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_SEED"] = "1"
        app.launchEnvironment["UITEST_RESET"] = "1"
        if name.contains("testAddBillShowsPaywallWhenFreeLimitReached") {
            app.launchEnvironment["UITEST_FREE_BILL_LIMIT"] = "0"
        }
        if name.contains("testSettingsCSVExportFlow") {
            app.launchEnvironment["UITEST_FORCE_PRO"] = "1"
        }
        app.launch()
    }

    func testDashboardShowsCoreSections() {
        XCTAssertTrue(app.staticTexts["Overdue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Due Soon"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Upcoming"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Paid This Month"].waitForExistence(timeout: 5))
    }

    func testDashboardMetricTilesAreVisibleAndHittable() {
        let overdueLabel = app.staticTexts["Overdue"]
        let dueSoonLabel = app.staticTexts["Due Soon"]
        let upcomingLabel = app.staticTexts["Upcoming"]
        let paidLabel = app.staticTexts["Paid This Month"]

        XCTAssertTrue(overdueLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(dueSoonLabel.exists)
        XCTAssertTrue(upcomingLabel.exists)
        XCTAssertTrue(paidLabel.exists)
        XCTAssertTrue(overdueLabel.isHittable)
    }

    func testNavigateDashboardToDetailAndBack() {
        let billCell = app.staticTexts["Home Utilities"]
        XCTAssertTrue(billCell.waitForExistence(timeout: 5))
        billCell.tap()

        XCTAssertTrue(app.navigationBars["Home Utilities"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Bill Due Tracker"].waitForExistence(timeout: 5))
    }

    func testQuickAddSubscriptionCadenceFields() {
        let addButton = app.buttons["dashboard.addBill"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let categoryButton = app.buttons["quickadd.category"]
        if categoryButton.waitForExistence(timeout: 2) {
            categoryButton.tap()
        } else {
            let categoryPicker = app.pickers["quickadd.category"]
            XCTAssertTrue(categoryPicker.waitForExistence(timeout: 5))
            categoryPicker.tap()
        }

        if app.buttons["Subscription"].waitForExistence(timeout: 2) {
            app.buttons["Subscription"].tap()
        } else {
            XCTAssertTrue(app.staticTexts["Subscription"].waitForExistence(timeout: 5))
            app.staticTexts["Subscription"].tap()
        }

        let cadencePicker = app.segmentedControls["quickadd.cadence"].firstMatch
        XCTAssertTrue(cadencePicker.waitForExistence(timeout: 5))

        let dueDatePicker = app.datePickers["quickadd.dueDate"].firstMatch
        XCTAssertTrue(dueDatePicker.waitForExistence(timeout: 5))

        cadencePicker.buttons["Yearly"].tap()
        XCTAssertTrue(dueDatePicker.exists)

        cadencePicker.buttons["Monthly"].tap()
        XCTAssertTrue(dueDatePicker.exists)
    }

    func testTimelineMonthFilterIsAccessible() {
        app.tabBars.buttons["Timeline"].tap()
        XCTAssertTrue(app.navigationBars["Monthly Timeline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["timeline.monthPicker"].waitForExistence(timeout: 5))
    }

    func testDashboardQuickEditActionOpensEditFlow() {
        let editButton = app.buttons["dashboard.quickAction.edit"].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        XCTAssertTrue(app.navigationBars["Edit Bill"].waitForExistence(timeout: 5))
        app.navigationBars["Edit Bill"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Bill Due Tracker"].waitForExistence(timeout: 5))
    }

    func testDashboardQuickMarkPaidActionDoesNotFail() {
        let markPaidButton = app.buttons["dashboard.quickAction.markPaid"].firstMatch
        XCTAssertTrue(markPaidButton.waitForExistence(timeout: 5))
        markPaidButton.tap()

        XCTAssertTrue(app.navigationBars["Bill Due Tracker"].exists)
        XCTAssertFalse(app.alerts["Action Failed"].exists)
    }

    func testTimelineQuickEditActionOpensEditFlow() {
        app.tabBars.buttons["Timeline"].tap()
        XCTAssertTrue(app.navigationBars["Monthly Timeline"].waitForExistence(timeout: 5))

        let editButton = app.buttons["timeline.quickAction.edit"].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        XCTAssertTrue(app.navigationBars["Edit Bill"].waitForExistence(timeout: 5))
        app.navigationBars["Edit Bill"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Monthly Timeline"].waitForExistence(timeout: 5))
    }

    func testAddBillShowsPaywallWhenFreeLimitReached() {
        let addButton = app.buttons["dashboard.addBill"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        XCTAssertTrue(app.navigationBars["Upgrade"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.primaryCta"].exists)
    }

    func testSettingsNotificationHealthAndSelfTest() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Notifications"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Enabled Reminder Stages"].exists)

        let sendTestButton = app.buttons["settings.sendTest"]
        XCTAssertTrue(sendTestButton.waitForExistence(timeout: 5))
        sendTestButton.tap()

        let alert = app.alerts["Bill Due Tracker"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["OK"].tap()
    }

    func testSettingsReminderTrustIndicatorsVisible() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Reminder Sync"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Permission"].exists)

        let freshnessMessage = app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                "Schedules",
                "Reconcile"
            )
        ).firstMatch
        XCTAssertTrue(freshnessMessage.waitForExistence(timeout: 5))
    }

    func testSettingsCSVExportFlow() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let exportButton = app.buttons["settings.exportCSV"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()

        let alert = app.alerts["Bill Due Tracker"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["OK"].tap()
    }

    func testSettingsBackupCreationFlow() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let backupButton = app.buttons["settings.createBackup"]
        XCTAssertTrue(backupButton.waitForExistence(timeout: 5))
        backupButton.tap()

        let alert = app.alerts["Bill Due Tracker"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["OK"].tap()
    }

    private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed)
    }
}
