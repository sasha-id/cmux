import Foundation

struct SessionWorkspaceTabSnapshot: Codable, Sendable {
    var id: UUID
    var title: String
    var isFocused: Bool
    var layout: SessionWorkspaceLayoutSnapshot
    var panels: [SessionPanelSnapshot]
}
