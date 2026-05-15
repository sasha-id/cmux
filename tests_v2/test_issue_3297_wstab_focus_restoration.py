#!/usr/bin/env python3
"""Regression for issue #3297 (and #1362): switching workspace tabs preserves
the previously-focused pane and the terminal first-responder within each tab.

Behavior under test: after splitting a pane in tab A, focusing the right pane,
switching to tab B and back to A, the right pane must still be focused and the
focused surface must accept keystrokes (first-responder restored).
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from cmux import cmux, cmuxError


SOCKET_PATH = os.environ.get("CMUX_SOCKET_PATH", "/tmp/cmux-debug.sock")


def _must(cond: bool, msg: str) -> None:
    if not cond:
        raise cmuxError(msg)


def main() -> int:
    with cmux(SOCKET_PATH) as c:
        workspace_id = (c._call("workspace.list", {}) or {})["workspaces"][0]["id"]

        # Workspace starts with one tab (call it A). Split it horizontally so it has two panes.
        tabs = c.wstab_list(workspace_id)
        tab_a = tabs[0]["id"]
        c.wstab_focus(tab_a)

        # Find the pane in tab A, split it, and focus the new (right) pane.
        panes = (c._call("pane.list", {"workspace_id": workspace_id}) or {}).get("panes", [])
        _must(len(panes) >= 1, f"tab A should have at least one pane: {panes}")
        original_pane = panes[0]["id"]
        c._call("surface.create", {"workspace_id": workspace_id, "pane": original_pane, "split_orientation": "horizontal"})

        panes_after_split = (c._call("pane.list", {"workspace_id": workspace_id}) or {}).get("panes", [])
        _must(len(panes_after_split) == 2, f"tab A should have 2 panes after split: {panes_after_split}")
        right_pane = next(p["id"] for p in panes_after_split if p["id"] != original_pane)
        c._call("pane.focus", {"pane_id": right_pane})

        # Create a second tab (B) and focus it, then return to A.
        tab_b = c.wstab_create(workspace_id, title="B")
        c.wstab_focus(tab_b["id"])
        c.wstab_focus(tab_a)

        # Check 1: the focused pane inside tab A is the right (previously-focused) pane.
        focus_state = c._call("identify", {}) or {}
        focused_pane = (focus_state.get("focused") or {}).get("pane_id")
        _must(focused_pane == right_pane,
              f"after wstab.focus(A), the right pane should regain focus; got {focused_pane}, expected {right_pane}")

        # Check 2: the focused surface accepts keystrokes (first-responder is restored).
        # `surface.is_first_responder` returns true when the AppKit window's first responder is
        # the terminal view of the focused surface.
        fr_state = c._call("surface.is_first_responder", {}) or {}
        _must(fr_state.get("is_first_responder") is True,
              f"focused surface must be AppKit first responder after wstab.focus; got {fr_state}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
