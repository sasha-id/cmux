import Foundation
import Bonsplit

// MARK: - Workspace tab actions

@MainActor
extension Workspace {
    /// Create a new workspace tab with an optional title.
    /// Returns the new outer tab ID so callers (socket handler, right-click menu) can
    /// reference the freshly-created tab. The `didCreateTab` delegate callback spins up
    /// the inner BonsplitController and seeds it with one default terminal surface.
    @discardableResult
    func createWorkspaceTab(title: String? = nil) -> Bonsplit.TabID? {
        return outerBonsplitController.createTab(title: title ?? self.title, icon: nil)
    }

    func selectNextWorkspaceTab() {
        outerBonsplitController.selectNextTab()
    }

    func selectPreviousWorkspaceTab() {
        outerBonsplitController.selectPreviousTab()
    }

    func selectWorkspaceTab(at index: Int) {
        let ids = outerBonsplitController.allTabIds
        guard index < ids.count else { return }
        outerBonsplitController.selectTab(ids[index])
    }

    /// Close the current workspace tab applying the LastSurfaceCloseShortcutSettings policy
    /// when only one outer tab remains (Task E3).
    func closeCurrentWorkspaceTab() {
        guard let currentId = currentOuterTabId else { return }
        if outerBonsplitController.allTabIds.count == 1 {
            // Last workspace tab: apply the user-configured close policy.
            if LastSurfaceCloseShortcutSettings.closesWorkspace() {
                let manager = owningTabManager
                    ?? AppDelegate.shared?.tabManagerFor(tabId: id)
                    ?? AppDelegate.shared?.tabManager
                manager?.closeWorkspaceFromCloseTabGesture(self)
            }
            // If closesWorkspace() == false, policy is "keep workspace open" — do nothing.
            return
        }
        outerBonsplitController.closeTab(currentId)
    }

    /// Close the workspace tab identified by `outerTabId` directly (no policy check).
    /// Used by the socket layer (Task F2) where the caller has already resolved the id.
    func closeWorkspaceTab(_ outerTabId: Bonsplit.TabID) {
        outerBonsplitController.closeTab(outerTabId)
    }

    /// Promote the pane identified by `paneId` in the current inner Bonsplit to its own
    /// new workspace tab.
    ///
    /// The promoted surface is detached from the source inner Bonsplit (the source pane
    /// auto-closes via `autoCloseEmptyPanes: true`), a new outer tab is created (which
    /// seeds a placeholder terminal), and the promoted surface is re-attached to the new
    /// inner Bonsplit's first pane after the placeholder is removed.
    ///
    /// Note: The drag-and-drop variant of this gesture (Phase G) reuses this method.
    func promotePane(_ paneId: Bonsplit.PaneID) {
        guard let inner = currentInnerBonsplit else { return }

        // Find the surface tab in the specified pane.
        let surfaceTabsInPane = inner.tabs(inPane: paneId)
        guard let surfaceTab = surfaceTabsInPane.first else { return }
        let surfaceTabId = surfaceTab.id
        guard let panelId = panelIdFromSurfaceId(surfaceTabId) else { return }

        // Derive a title from the panel's cached title or the workspace title.
        let tabTitle = panelCustomTitles[panelId]
            ?? panelTitles[panelId]
            ?? self.title

        // 1. Detach the surface from the source inner Bonsplit.
        //    `detachSurface` closes the tab in `bonsplitController` (== currentInnerBonsplit),
        //    removes the panel from `panels`, and returns a `DetachedSurfaceTransfer` payload.
        guard let detached = detachSurface(panelId: panelId) else { return }

        // 2. Create the new outer tab. `handleOuterDidCreateTab` fires synchronously and seeds
        //    one default terminal surface (the placeholder) in the new inner Bonsplit.
        guard let newOuterTabId = outerBonsplitController.createTab(title: tabTitle, icon: nil) else {
            // Detach failed to create the target — re-attach to the source workspace so the
            // panel is not lost. Use a best-effort attach back to the first available pane.
            if let fallbackPaneId = currentInnerBonsplit?.allPaneIds.first {
                _ = attachDetachedSurface(detached, inPane: fallbackPaneId, focus: false)
            }
            return
        }

        guard let newInner = innerBonsplits[newOuterTabId],
              let newPaneId = newInner.allPaneIds.first else { return }

        // 3. Remove the placeholder surface that was auto-seeded in the new inner Bonsplit.
        let placeholderTabs = newInner.tabs(inPane: newPaneId)
        for placeholder in placeholderTabs {
            let placeholderTabId = placeholder.id
            guard let placeholderPanelId = panelIdFromSurfaceId(placeholderTabId) else { continue }
            _ = discardClosedPanelLifecycleState(
                panelId: placeholderPanelId,
                tabId: placeholderTabId,
                paneId: newPaneId,
                panel: panels[placeholderPanelId],
                origin: "promote_pane_placeholder",
                closePanel: true,
                publishSurfaceClosedEvent: false,
                clearSurfaceNotifications: false,
                requestTransferredRemoteCleanup: false,
                cleanupControllerSurfaceState: true
            )
            _ = newInner.closeTab(placeholderTabId, inPane: newPaneId)
        }

        // 4. Select the new outer tab so `bonsplitController` resolves to `newInner`,
        //    then attach the promoted surface to the new inner Bonsplit's first pane.
        outerBonsplitController.selectTab(newOuterTabId)
        _ = attachDetachedSurface(detached, inPane: newPaneId, focus: true)
    }
}

// MARK: - Socket-driven actions

@MainActor
extension Workspace {

    // MARK: Transfer (wstab.move_to_workspace)

    /// Move an entire workspace tab (its inner Bonsplit + all panels) to a destination workspace.
    /// Preserves surface UUIDs, terminal state, and panel subscriptions. The source's outer tab
    /// is removed WITHOUT disposing panels — those are moved into the destination first.
    ///
    /// Called by the `wstab.move_to_workspace` socket verb (Task F5).
    func transferWorkspaceTab(_ outerTabId: Bonsplit.TabID, to destination: Workspace) {
        guard let inner = innerBonsplits[outerTabId],
              let tabInfo = outerBonsplitController.tab(outerTabId) else { return }
        let title = tabInfo.title

        // Collect the surface (panel) IDs in this tab.
        let panelIds: [UUID] = inner.allTabIds.compactMap { panelIdFromSurfaceId($0) }

        // Move Panel instances and subscriptions to the destination WITHOUT dispose.
        for panelId in panelIds {
            if let panel = panels.removeValue(forKey: panelId) {
                destination.panels[panelId] = panel
            }
            if let sub = panelSubscriptions.removeValue(forKey: panelId) {
                destination.panelSubscriptions[panelId] = sub
            }
        }

        // Hand the inner Bonsplit reference over wholesale, preserving tab/pane IDs.
        // Pre-register BEFORE calling `createTab(id:...)` so `handleOuterDidCreateTab`
        // on the destination can detect the transfer via `isProgrammaticOuterTabTransfer`.
        innerBonsplits.removeValue(forKey: outerTabId)
        destination.innerBonsplits[outerTabId] = inner
        inner.delegate = destination  // future delegate callbacks route to destination

        // Create a matching outer tab on the destination with the same TabID so external
        // references (event subscribers, persistence) keep working.
        // Set the transfer flag to suppress the default "new tab = new inner + seed" behavior.
        destination.isProgrammaticOuterTabTransfer = true
        defer { destination.isProgrammaticOuterTabTransfer = false }
        destination.outerBonsplitController.createTab(id: outerTabId, title: title, icon: nil)

        // Close the source outer entry. Panels are already moved out, so didCloseTab
        // will find no panels to dispose.
        outerBonsplitController.closeTab(outerTabId)
    }

    // MARK: Reorder (wstab.reorder)

    func reorderWorkspaceTab(_ outerTabId: Bonsplit.TabID, before: Bonsplit.TabID?, after: Bonsplit.TabID?) {
        let allIds = outerBonsplitController.allTabIds
        guard let pane = outerBonsplitController.allPaneIds.first,
              let srcIdx = allIds.firstIndex(of: outerTabId) else { return }
        let anchor = before ?? after
        guard let anchor = anchor, let anchorIdx = allIds.firstIndex(of: anchor) else { return }
        let targetIdx = (before != nil) ? anchorIdx : anchorIdx + 1
        let normalizedIdx = targetIdx > srcIdx ? targetIdx - 1 : targetIdx
        outerBonsplitController.moveTab(outerTabId, toPane: pane, atIndex: normalizedIdx)
    }

    // MARK: Last-focused tracking (wstab.last)

    /// The outer tab ID that was focused just before the current one.
    /// Updated by `recordOuterTabFocusChange` whenever the outer tab changes.
    var lastFocusedOuterTabId: Bonsplit.TabID? {
        get { _lastFocusedOuterTabId }
        set { _lastFocusedOuterTabId = newValue }
    }

    func recordOuterTabFocusChange(from previous: Bonsplit.TabID?, to next: Bonsplit.TabID) {
        if let previous = previous, previous != next {
            _lastFocusedOuterTabId = previous
        }
    }

    func focusLastWorkspaceTab() {
        guard let last = _lastFocusedOuterTabId else { return }
        outerBonsplitController.selectTab(last)
    }
}

// MARK: - Routing helpers

@MainActor
extension Workspace {
    /// All inner Bonsplit controllers in outer-tab order.
    var allInnerBonsplits: [BonsplitController] {
        outerBonsplitController.allTabIds.compactMap { innerBonsplits[$0] }
    }

    // MARK: - UI snapshot helpers

    /// Build a value-type snapshot for the given outer tab. Used by `WorkspaceContentView`
    /// to satisfy the snapshot-boundary rule: the outer-BonsplitView closure reads only
    /// from this snapshot rather than capturing `Workspace` observables directly.
    func snapshot(forOuterTab outerTabId: Bonsplit.TabID) -> WorkspaceTabContentSnapshot? {
        guard let inner = innerBonsplits[outerTabId] else { return nil }
        return WorkspaceTabContentSnapshot(
            workspaceId: id,
            outerTabId: outerTabId,
            innerBonsplitObjectId: ObjectIdentifier(inner)
        )
    }

    /// Recompute and push the paneCount affordance for the outer tab that owns `inner`.
    /// Sets `nil` when the inner controller has ≤ 1 pane (no glyph rendered).
    func refreshOuterTabPaneCount(forInner inner: BonsplitController) {
        guard let outerTabId = innerBonsplits.first(where: { $0.value === inner })?.key else { return }
        let count = inner.allPaneIds.count
        let paneCount: Int? = count > 1 ? count : nil
        outerBonsplitController.updateTab(outerTabId, paneCount: paneCount)
    }

    /// Returns the outer tab ID that contains the given inner-tab (surface) ID.
    func outerTab(forSurfaceTabId surfaceTabId: Bonsplit.TabID) -> Bonsplit.TabID? {
        for (outerTabId, inner) in innerBonsplits {
            if inner.tab(surfaceTabId) != nil {
                return outerTabId
            }
        }
        return nil
    }

    /// Returns the outer tab ID, inner controller, and inner tab ID for a given surface panel UUID.
    func locateSurface(panelId: UUID) -> (outerTabId: Bonsplit.TabID, inner: BonsplitController, innerTabId: Bonsplit.TabID)? {
        guard let surfaceTabId = surfaceIdFromPanelId(panelId) else { return nil }
        for (outerTabId, inner) in innerBonsplits {
            if inner.tab(surfaceTabId) != nil {
                return (outerTabId, inner, surfaceTabId)
            }
        }
        return nil
    }
}
