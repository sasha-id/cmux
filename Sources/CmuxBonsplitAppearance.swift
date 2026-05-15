import Bonsplit
import CoreGraphics
import Foundation

/// Appearance presets for the two Bonsplit layers in the splits-inside-tabs model.
///
/// The outer Bonsplit hosts the workspace-level tab strip; the inner Bonsplit hosts
/// the per-tab split pane tree (with its own compact pane-header tab strip).
enum CmuxBonsplitAppearance {
    /// Appearance for the workspace-level outer Bonsplit tab strip.
    /// Visual distinction: a touch taller than the pane header and explicitly hides
    /// split buttons (outer has only one pane, so splits are meaningless).
    static let workspaceTabBar: BonsplitConfiguration.Appearance = {
        var a = BonsplitConfiguration.Appearance.default
        a.showSplitButtons = false
        a.tabBarHeight = 28
        return a
    }()

    /// Appearance for the per-tab inner Bonsplit tab strip, repurposed as a pane header.
    /// Visual distinction: compact height, split buttons visible (the inner strip is where
    /// the user creates splits within a workspace tab).
    static let paneHeader: BonsplitConfiguration.Appearance = {
        var a = BonsplitConfiguration.Appearance.compact
        a.showSplitButtons = true
        a.tabBarHeight = 22
        return a
    }()
}
