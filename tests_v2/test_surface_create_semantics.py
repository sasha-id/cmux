#!/usr/bin/env python3
"""v2 regression: surface.create new semantics under the workspace-tab model.

- With a `pane` argument that already has its one surface: auto-split that pane.
- Without a `pane` argument: create a new workspace tab.
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

        # Case 1: surface.create with a full pane should auto-split.
        panes_before = c._call("pane.list", {"workspace_id": workspace_id}) or {}
        pane_count_before = len(panes_before.get("panes", []))
        target_pane = panes_before["panes"][0]["id"]

        result = c._call("surface.create", {
            "workspace_id": workspace_id,
            "pane": target_pane,
            "split_orientation": "horizontal",
        }) or {}
        _must(bool(result.get("surface_id")), f"surface.create should return surface_id: {result}")
        _must(result.get("pane_id") and result["pane_id"] != target_pane,
              f"auto-split should produce a NEW pane id: {result}")

        panes_after = c._call("pane.list", {"workspace_id": workspace_id}) or {}
        _must(len(panes_after.get("panes", [])) == pane_count_before + 1,
              f"pane count should grow by 1; got {len(panes_after.get('panes', []))} - {pane_count_before}")

        # Case 2: surface.create with no pane should create a new workspace tab.
        wstabs_before = c.wstab_list(workspace_id)
        result2 = c._call("surface.create", {"workspace_id": workspace_id}) or {}
        _must(bool(result2.get("wstab_id")), f"surface.create with no pane should return wstab_id: {result2}")
        _must(len(c.wstab_list(workspace_id)) == len(wstabs_before) + 1,
              "wstab count should grow by 1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
