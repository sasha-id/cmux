import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

final class SessionWorkspaceTabSnapshotTests: XCTestCase {
    func testTabSnapshotRoundTripsThroughCodable() throws {
        let panel = SessionPanelSnapshot.terminalFixture()
        let pane = SessionPaneLayoutSnapshot(panelIds: [panel.id], selectedPanelId: panel.id)
        let layout = SessionWorkspaceLayoutSnapshot.pane(pane)
        let tab = SessionWorkspaceTabSnapshot(
            id: UUID(),
            title: "Tab 1",
            isFocused: true,
            layout: layout,
            panels: [panel]
        )

        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(SessionWorkspaceTabSnapshot.self, from: data)

        XCTAssertEqual(decoded.id, tab.id)
        XCTAssertEqual(decoded.title, "Tab 1")
        XCTAssertTrue(decoded.isFocused)
    }
}

extension SessionPanelSnapshot {
    /// Test helper: produce a minimal terminal-kind panel snapshot.
    static func terminalFixture(
        id: UUID = UUID(),
        title: String? = "test",
        directory: String? = "/tmp"
    ) -> SessionPanelSnapshot {
        SessionPanelSnapshot(
            id: id,
            type: .terminal,
            title: title,
            customTitle: nil,
            directory: directory,
            isPinned: false,
            isManuallyUnread: false,
            hasUnreadIndicator: nil,
            gitBranch: nil,
            listeningPorts: [],
            ttyName: nil,
            terminal: SessionTerminalPanelSnapshot(
                workingDirectory: directory,
                scrollback: nil,
                agent: nil,
                tmuxStartCommand: nil
            ),
            browser: nil,
            markdown: nil,
            filePreview: nil,
            rightSidebarTool: nil
        )
    }
}
