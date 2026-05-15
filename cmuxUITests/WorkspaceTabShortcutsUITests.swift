import XCTest

/// E2E coverage for workspace-tab keyboard shortcuts (Cmd+T new tab, Cmd+1..9 select tab).
/// These tests run on CI via: gh workflow run test-e2e.yml --field test_filter="WorkspaceTabShortcutsUITests"
final class WorkspaceTabShortcutsUITests: XCTestCase {
    private let launchTimeout: TimeInterval = 20.0

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCmdTCreatesNewWorkspaceTab() {
        let app = XCUIApplication()
        app.launchArguments = ["--cmux-uitest-fresh-workspace"]
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: launchTimeout),
            "App did not launch within \(launchTimeout)s"
        )

        // Wait for the workspace content area.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        let initialCount = tabBar.buttons.count

        // Cmd+T is bound to newWorkspaceTab in Phase E.
        app.typeKey("t", modifierFlags: .command)

        // Wait for tab count to increase.
        let expectation = XCTestExpectation(description: "Tab count increases after Cmd+T")
        var tabCountIncreased = false
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.1)
            if tabBar.buttons.count > initialCount {
                tabCountIncreased = true
                break
            }
        }
        XCTAssertTrue(tabCountIncreased,
                      "Cmd+T should add a new workspace tab; initial=\(initialCount) current=\(tabBar.buttons.count)")
        _ = expectation
    }

    func testCmdNumberSelectsNthWorkspaceTab() {
        let app = XCUIApplication()
        app.launchArguments = ["--cmux-uitest-fresh-workspace"]
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: launchTimeout),
            "App did not launch within \(launchTimeout)s"
        )

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Create two extra tabs so we have 3 total.
        app.typeKey("t", modifierFlags: .command)
        app.typeKey("t", modifierFlags: .command)

        // Wait for 3 tabs.
        var reachedThree = false
        for _ in 0..<30 {
            Thread.sleep(forTimeInterval: 0.1)
            if tabBar.buttons.count >= 3 {
                reachedThree = true
                break
            }
        }
        XCTAssertTrue(reachedThree, "Expected 3 workspace tabs after two Cmd+T presses; got \(tabBar.buttons.count)")
        guard reachedThree else { return }

        // Focus the third tab (Cmd+3), then press Cmd+1 and check first tab is selected.
        app.typeKey("3", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.2)

        app.typeKey("1", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.2)

        // The first tab button should become selected after Cmd+1.
        let firstTab = tabBar.buttons.element(boundBy: 0)
        XCTAssertTrue(firstTab.isSelected,
                      "Cmd+1 should select the first workspace tab")
    }
}
