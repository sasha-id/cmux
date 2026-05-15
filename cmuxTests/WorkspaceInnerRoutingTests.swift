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
}
