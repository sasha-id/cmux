import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

final class SessionWorkspaceTabsMigrationTests: XCTestCase {
    /// Legacy workspace with a single pane containing a single tab.
    /// Expected outcome: wrap into a single workspace tab with the same pane.
    func testLegacySinglePaneSingleTabWrapsIntoOneWorkspaceTab() throws {
        let panel = SessionPanelSnapshot.terminalFixture()
        let layout = SessionWorkspaceLayoutSnapshot.pane(
            SessionPaneLayoutSnapshot(panelIds: [panel.id], selectedPanelId: panel.id)
        )
        let legacy = SessionWorkspaceSnapshot.fixture(layout: layout, panels: [panel])

        let migrated = SessionPersistence.normalizeWorkspaceSnapshot(legacy)

        XCTAssertNotNil(migrated.tabs)
        XCTAssertEqual(migrated.tabs?.count, 1)
        XCTAssertEqual(migrated.tabs?[0].panels.count, 1)
        XCTAssertEqual(migrated.tabs?[0].panels[0].id, panel.id)
    }

    /// Legacy workspace with one pane containing two tabs (selected = first).
    /// Expected outcome: two workspace tabs.
    /// Tab[0] is the lifted-layout tab containing the selected panel in its single pane.
    /// Tab[1] is the non-selected panel as its own single-pane workspace tab.
    func testLegacySinglePaneMultiTabFlattens() throws {
        let p1 = SessionPanelSnapshot.terminalFixture(id: UUID(), title: "first")
        let p2 = SessionPanelSnapshot.terminalFixture(id: UUID(), title: "second")
        let layout = SessionWorkspaceLayoutSnapshot.pane(
            SessionPaneLayoutSnapshot(panelIds: [p1.id, p2.id], selectedPanelId: p1.id)
        )
        let legacy = SessionWorkspaceSnapshot.fixture(layout: layout, panels: [p1, p2])

        let migrated = SessionPersistence.normalizeWorkspaceSnapshot(legacy)

        XCTAssertEqual(migrated.tabs?.count, 2)
        XCTAssertEqual(migrated.tabs?[0].panels.first?.id, p1.id)
        XCTAssertEqual(migrated.tabs?[1].panels.first?.id, p2.id)
    }

    /// Legacy workspace with a 2-pane split. Each pane has two tabs.
    /// Expected outcome: tab[0] holds the split layout with each pane's selected panel as the sole entry.
    /// tab[1..N] are the non-selected panels lifted to single-pane workspace tabs in pane-traversal order.
    func testLegacyMultiPaneMultiTabFlattens() throws {
        let leftSelected = SessionPanelSnapshot.terminalFixture(id: UUID(), title: "left-selected")
        let leftOther = SessionPanelSnapshot.terminalFixture(id: UUID(), title: "left-other")
        let rightSelected = SessionPanelSnapshot.terminalFixture(id: UUID(), title: "right-selected")
        let rightOther = SessionPanelSnapshot.terminalFixture(id: UUID(), title: "right-other")

        let leftPane = SessionPaneLayoutSnapshot(panelIds: [leftSelected.id, leftOther.id], selectedPanelId: leftSelected.id)
        let rightPane = SessionPaneLayoutSnapshot(panelIds: [rightSelected.id, rightOther.id], selectedPanelId: rightSelected.id)
        let split = SessionSplitLayoutSnapshot(
            orientation: .horizontal,
            dividerPosition: 0.5,
            first: .pane(leftPane),
            second: .pane(rightPane)
        )
        let layout = SessionWorkspaceLayoutSnapshot.split(split)
        let legacy = SessionWorkspaceSnapshot.fixture(
            layout: layout,
            panels: [leftSelected, leftOther, rightSelected, rightOther]
        )

        let migrated = SessionPersistence.normalizeWorkspaceSnapshot(legacy)

        XCTAssertEqual(migrated.tabs?.count, 3)
        XCTAssertNotNil(migrated.tabs?[0].layout)
        // Lifted tabs preserve pane-traversal order (left first, then right).
        XCTAssertEqual(migrated.tabs?[1].panels.first?.id, leftOther.id)
        XCTAssertEqual(migrated.tabs?[2].panels.first?.id, rightOther.id)
    }

    /// New-shape save: pass-through, no normalization.
    func testNewShapeIsPreserved() throws {
        let panel = SessionPanelSnapshot.terminalFixture()
        let tab = SessionWorkspaceTabSnapshot(
            id: UUID(),
            title: "Editor",
            isFocused: true,
            layout: .pane(SessionPaneLayoutSnapshot(panelIds: [panel.id], selectedPanelId: panel.id)),
            panels: [panel]
        )
        let snapshot = SessionWorkspaceSnapshot.fixture(tabs: [tab])

        let migrated = SessionPersistence.normalizeWorkspaceSnapshot(snapshot)

        XCTAssertEqual(migrated.tabs?.count, 1)
        XCTAssertEqual(migrated.tabs?[0].title, "Editor")
        XCTAssertNil(migrated.layout, "legacy field must be cleared after normalization")
    }
}

extension SessionWorkspaceSnapshot {
    static func fixture(
        layout: SessionWorkspaceLayoutSnapshot? = nil,
        panels: [SessionPanelSnapshot]? = nil,
        tabs: [SessionWorkspaceTabSnapshot]? = nil
    ) -> SessionWorkspaceSnapshot {
        SessionWorkspaceSnapshot(
            processTitle: "test",
            customTitle: nil,
            customDescription: nil,
            customColor: nil,
            isPinned: false,
            isManuallyUnread: nil,
            hasUnreadIndicator: nil,
            terminalScrollBarHidden: nil,
            currentDirectory: "/tmp",
            focusedPanelId: nil,
            layout: layout,
            panels: panels,
            tabs: tabs,
            statusEntries: [],
            logEntries: [],
            progress: nil,
            gitBranch: nil,
            remote: nil
        )
    }
}
