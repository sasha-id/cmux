import Foundation
import Bonsplit

/// Immutable value snapshot of everything the outer-tab content closure needs.
/// Passing this through the BonsplitView closure instead of `Workspace` itself
/// prevents the closure from capturing `@Published` observables on Workspace,
/// which would otherwise re-render every row whenever any `@Published` field
/// on Workspace changes (the snapshot-boundary rule in CLAUDE.md).
///
/// The trick: `ObjectIdentifier(innerBonsplit)` is stable per inner controller and
/// Equatable. When the user switches workspace tabs, the snapshot's `outerTabId` and
/// `innerBonsplitObjectId` both change, so SwiftUI re-evaluates the closure body and
/// looks up the right inner Bonsplit. When *inside* an inner controller the user types
/// or splits, the snapshot remains equal (same outer tab, same inner controller
/// identity), so the outer closure doesn't re-evaluate.
struct WorkspaceTabContentSnapshot: Equatable {
    let workspaceId: UUID
    let outerTabId: Bonsplit.TabID
    /// Identity proxy for the inner BonsplitController; doesn't trigger SwiftUI invalidation.
    let innerBonsplitObjectId: ObjectIdentifier

    static func == (lhs: WorkspaceTabContentSnapshot, rhs: WorkspaceTabContentSnapshot) -> Bool {
        lhs.workspaceId == rhs.workspaceId &&
        lhs.outerTabId == rhs.outerTabId &&
        lhs.innerBonsplitObjectId == rhs.innerBonsplitObjectId
    }
}
