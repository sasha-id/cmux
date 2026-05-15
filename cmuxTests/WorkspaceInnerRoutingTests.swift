import XCTest
import Bonsplit

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@MainActor
final class WorkspaceInnerRoutingTests: XCTestCase {
    func testFreshWorkspaceHasExactlyOneOuterTabWithOneInnerBonsplit() {
        let workspace = Workspace()
        XCTAssertEqual(workspace.outerBonsplitController.allTabIds.count, 1)
        XCTAssertEqual(workspace.innerBonsplits.count, 1)
        XCTAssertNotNil(workspace.currentInnerBonsplit)
    }

    func testCurrentInnerBonsplitTracksOuterSelection() {
        let workspace = Workspace()
        let initialInner = workspace.currentInnerBonsplit
        guard let secondOuterTab = workspace.outerBonsplitController.createTab(title: "B", icon: nil) else {
            XCTFail("outerBonsplitController.createTab returned nil")
            return
        }
        let secondInner = workspace.innerBonsplits[secondOuterTab]
        workspace.outerBonsplitController.selectTab(secondOuterTab)
        XCTAssertTrue(workspace.currentInnerBonsplit === secondInner)
        XCTAssertFalse(workspace.currentInnerBonsplit === initialInner)
    }

    func testOuterTabForSurfaceReturnsContainingOuterTab() {
        let workspace = Workspace()
        guard let firstOuterTab = workspace.outerBonsplitController.allTabIds.first,
              let firstInner = workspace.innerBonsplits[firstOuterTab] else {
            XCTFail("fixture should have one outer tab")
            return
        }
        // The inner pane is already seeded with one surface tab during workspace init.
        // Use that existing surface tab (creating a second would be vetoed by C2).
        guard let surfaceTab = firstInner.allTabIds.first else {
            XCTFail("inner Bonsplit should have exactly one surface tab after init")
            return
        }

        let resolved = workspace.outerTab(forSurfaceTabId: surfaceTab)
        XCTAssertEqual(resolved, firstOuterTab)
    }

    // MARK: - C1 tests

    func testOuterDidCreateTabSpinsUpFreshInnerBonsplit() {
        let workspace = Workspace()
        let beforeCount = workspace.innerBonsplits.count

        guard let newOuterTab = workspace.outerBonsplitController.createTab(title: "X", icon: nil) else {
            XCTFail("outerBonsplitController.createTab returned nil")
            return
        }

        XCTAssertEqual(workspace.innerBonsplits.count, beforeCount + 1,
                       "creating an outer tab must register a new inner Bonsplit")
        XCTAssertNotNil(workspace.innerBonsplits[newOuterTab],
                        "the new inner Bonsplit must be keyed by the new outer tab ID")
        XCTAssertEqual(
            workspace.innerBonsplits[newOuterTab]?.allPaneIds.count, 1,
            "fresh inner should have exactly one pane"
        )
    }

    func testOuterDidCloseTabTearsDownInnerAndPanels() {
        let workspace = Workspace()
        guard let newOuterTab = workspace.outerBonsplitController.createTab(title: "X", icon: nil) else {
            XCTFail("outerBonsplitController.createTab returned nil")
            return
        }
        XCTAssertNotNil(workspace.innerBonsplits[newOuterTab])

        workspace.outerBonsplitController.closeTab(newOuterTab)

        XCTAssertNil(workspace.innerBonsplits[newOuterTab],
                     "inner Bonsplit must be removed when outer tab closes")
    }

    // MARK: - C2 tests

    func testInnerShouldCreateTabVetoesWhenPaneAlreadyHasASurface() {
        let workspace = Workspace()
        guard let inner = workspace.currentInnerBonsplit,
              let pane = inner.allPaneIds.first else {
            XCTFail("fixture should have inner with one pane")
            return
        }
        // Inner already has one tab in its only pane (seeded during outer createTab).
        XCTAssertEqual(inner.tabs(inPane: pane).count, 1)

        let result = inner.createTab(title: "Second", icon: nil, inPane: pane)

        XCTAssertNil(result, "creating a second tab in the same inner pane should be vetoed")
        XCTAssertEqual(inner.tabs(inPane: pane).count, 1)
    }
}
