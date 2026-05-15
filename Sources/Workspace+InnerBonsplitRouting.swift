import Foundation
import Bonsplit

// MARK: - Routing helpers

@MainActor
extension Workspace {
    /// All inner Bonsplit controllers in outer-tab order.
    var allInnerBonsplits: [BonsplitController] {
        outerBonsplitController.allTabIds.compactMap { innerBonsplits[$0] }
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
