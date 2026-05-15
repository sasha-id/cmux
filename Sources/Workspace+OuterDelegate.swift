import Bonsplit
import Foundation

// MARK: - Outer Bonsplit delegate handlers

/// Handlers for delegate callbacks originating from `outerBonsplitController`.
/// The outer controller owns the workspace-level tab strip (one pane, N tabs, splits disabled).
/// Each outer tab corresponds to exactly one inner `BonsplitController`.
@MainActor
extension Workspace {

    // MARK: - Outer: shouldCreateTab / shouldCloseTab

    func handleOuterShouldCloseTab(_ tab: Bonsplit.Tab) -> Bool {
        // Allow closing outer tabs freely. If more sophisticated confirmation is
        // ever needed (e.g. "you have running processes in N panes"), add it here.
        return true
    }

    // MARK: - Outer: didCreateTab

    /// Called after the outer controller has added a new workspace tab.
    /// Spins up a fresh inner `BonsplitController` and seeds it with one terminal surface.
    ///
    /// Registration (`innerBonsplits[tab.id] = inner`) happens synchronously inside this
    /// callback, before returning to the outer controller. Any code that accesses
    /// `currentInnerBonsplit` after `createTab` returns will therefore find the new entry.
    func handleOuterDidCreateTab(_ tab: Bonsplit.Tab) {
        // During a `transferWorkspaceTab` call the inner controller is already registered
        // in `innerBonsplits` before `createTab(id:...)` fires this callback, so we must
        // NOT overwrite it or spawn a placeholder surface.
        if isProgrammaticOuterTabTransfer {
            // The transfer path pre-registered the inner Bonsplit; nothing to do here.
            return
        }
        let inner = makeInnerBonsplitController()
        // Register BEFORE calling any method that routes through bonsplitController /
        // currentInnerBonsplit, so the backing entry is present if anything queries it
        // while we seed the initial surface below.
        innerBonsplits[tab.id] = inner

        // Seed the new inner with a default terminal surface.
        spawnDefaultSurface(in: inner)
    }

    // MARK: - Outer: didCloseTab

    /// Called after the outer controller has removed a workspace tab.
    /// Tears down the corresponding inner Bonsplit and every panel it owns.
    func handleOuterDidCloseTab(_ tabId: Bonsplit.TabID) {
        guard let inner = innerBonsplits[tabId] else { return }

        // Collect every inner surface tab ID so we can dispose panels.
        let innerTabIds = inner.allTabIds

        for innerTabId in innerTabIds {
            guard let panelId = panelIdFromSurfaceId(innerTabId) else { continue }
            let panel = panels[panelId]
            discardClosedPanelLifecycleState(
                panelId: panelId,
                tabId: innerTabId,
                paneId: inner.allPaneIds.first,
                panel: panel,
                origin: "outer_tab_close",
                closePanel: true,
                publishSurfaceClosedEvent: true,
                clearSurfaceNotifications: true,
                requestTransferredRemoteCleanup: true,
                cleanupControllerSurfaceState: true
            )
        }

        innerBonsplits.removeValue(forKey: tabId)
    }

    // MARK: - Outer: didSelectTab (stub — Task H1 completes the body)

    // IMPORTANT: this body is intentionally a stub for Task H1's red/green regression.
    // Task H1 will implement inner pane focus + AppKit first-responder restoration.
    func handleOuterDidSelectTab(_ tab: Bonsplit.Tab) {
        // Track the previous outer tab for wstab.last (Phase F).
        // `didSelectTab` fires after the controller updated its selection, so `currentOuterTabId`
        // already returns `tab.id`. We use the helper that reads the stored previous value:
        // `recordOuterTabFocusChange` only updates _lastFocusedOuterTabId when `from != to`
        // and `from != nil`, so calling it with the last stored value is safe on re-entry.
        recordOuterTabFocusChange(from: _trackedOuterTabIdBeforeSelect, to: tab.id)
        _trackedOuterTabIdBeforeSelect = tab.id
        // TODO(H1): restore inner pane focus + AppKit first-responder. Wired in Task H1.
    }

    // MARK: - Factory helpers

    /// Create a configured inner BonsplitController and wire it as a delegate of self.
    func makeInnerBonsplitController() -> BonsplitController {
        let config = BonsplitConfiguration(
            allowSplits: true,
            allowCloseTabs: true,
            allowCloseLastPane: false,
            allowTabReordering: false,
            allowCrossPaneTabMove: false,
            autoCloseEmptyPanes: true,
            contentViewLifecycle: .keepAllAlive,
            newTabPosition: .current,
            appearance: CmuxBonsplitAppearance.paneHeader
        )
        let controller = BonsplitController(configuration: config)
        controller.delegate = self
        controller.contextMenuShortcuts = Self.buildContextMenuShortcuts()
        return controller
    }

    // Note: spawnDefaultSurface(in:) is defined in Workspace.swift where it can
    // access private helpers (configureTerminalPanel, inheritedTerminalConfig, etc.).
}

// MARK: - Routing shim (outer vs inner)

/// Extends the `BonsplitDelegate` conformance declared in `Workspace.swift` to add
/// `shouldCreateTab` / `didCreateTab`, and refactors every delegate method to dispatch
/// by controller identity (`controller === outerBonsplitController`).
@MainActor
extension Workspace {

    // MARK: shouldCreateTab / didCreateTab

    func splitTabBar(_ controller: BonsplitController, shouldCreateTab tab: Bonsplit.Tab, inPane pane: PaneID) -> Bool {
        if controller === outerBonsplitController {
            // Outer: always allow — workspace tabs can always be created.
            return true
        }
        return handleInnerShouldCreateTab(controller: controller, tab: tab, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didCreateTab tab: Bonsplit.Tab, inPane pane: PaneID) {
        if controller === outerBonsplitController {
            handleOuterDidCreateTab(tab)
            return
        }
        // Inner: existing logic (no-op; surface panels are created before createTab is called).
    }

    // MARK: Inner: shouldCreateTab veto

    /// Veto creating a second tab (surface) inside an inner pane via UI action.
    /// Each inner pane holds exactly one surface — this is the core invariant of the
    /// splits-inside-tabs model. A new surface in the same pane must go through a pane split.
    ///
    /// Programmatic creates (newTerminalSurface, newBrowserSurface, attachDetachedSurface, etc.)
    /// bypass the veto by setting `isProgrammaticInnerTabCreate = true` before calling
    /// `bonsplitController.createTab`. UI-triggered creates from the BonsplitView "+" button
    /// do not set this flag, so the invariant is enforced for all user actions.
    func handleInnerShouldCreateTab(
        controller: BonsplitController,
        tab: Bonsplit.Tab,
        inPane pane: PaneID
    ) -> Bool {
        // Allow programmatic creates that bypass the single-surface invariant.
        if isProgrammaticInnerTabCreate { return true }
        if !controller.tabs(inPane: pane).isEmpty {
            // Pane already has a surface. Veto the creation to enforce single-surface-per-pane.
            return false
        }
        // No existing surface — allow.
        return true
    }
}
