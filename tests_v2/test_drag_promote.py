#!/usr/bin/env python3
"""v2 regression: dragging an inner pane's surface onto the outer tab strip
promotes the surface into its own new workspace tab.

Tests two matrix paths from the G1 drag/drop matrix:
  - Inner-pane tab header → outer tab strip (same workspace): promote to new wstab
  - Inner-pane tab header → outer tab strip (different workspace): cross-workspace move

VM/CI run required for final validation (local execution not permitted per CLAUDE.md).
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


def _workspace_ids(c: cmux) -> list:
    resp = c._call("workspace.list", {}) or {}
    return [ws["id"] for ws in resp.get("workspaces", [])]


def test_promote_same_workspace(c: cmux) -> None:
    """Drag an inner surface to the outer tab strip of the same workspace → new wstab."""
    workspace_id = _workspace_ids(c)[0]

    # Ensure at least 2 panes so promoting one leaves a non-empty source.
    panes = (c._call("pane.list", {"workspace_id": workspace_id}) or {}).get("panes", [])
    if len(panes) < 2:
        first_surface_id = panes[0].get("selected_surface_id") or (panes[0].get("surface_ids") or [None])[0]
        _must(bool(first_surface_id), f"first pane has no surface: {panes[0]}")
        c._call("surface.create", {
            "workspace_id": workspace_id,
            "surface_id": first_surface_id,
            "split_orientation": "horizontal",
        })
        panes = (c._call("pane.list", {"workspace_id": workspace_id}) or {}).get("panes", [])
    _must(len(panes) >= 2, f"need >=2 panes after split; got {len(panes)}")

    before = c.wstab_list(workspace_id)
    before_ids = {t["id"] for t in before}
    source_pane = panes[0]
    surface_id = source_pane.get("selected_surface_id") or (source_pane.get("surface_ids") or [None])[0]
    _must(bool(surface_id), f"source pane must have a surface: {source_pane}")

    # Simulate the UI drag-and-drop via the dedicated socket verb.
    result = c.drag_surface_to_outer_strip(surface_id=surface_id, target_workspace_id=workspace_id)
    _must("error" not in result, f"promote_surface_drop failed: {result}")

    after = c.wstab_list(workspace_id)
    _must(
        len(after) == len(before) + 1,
        f"workspace tab count should grow by 1; before={len(before)} after={len(after)}",
    )
    new_wstabs = [t for t in after if t["id"] not in before_ids]
    _must(len(new_wstabs) == 1, f"exactly one new wstab expected; got {len(new_wstabs)}")
    new_wstab_surfaces = new_wstabs[0].get("surface_ids") or []
    _must(
        surface_id in new_wstab_surfaces,
        f"promoted surface {surface_id!r} must live in the new wstab; got {new_wstabs[0]}",
    )


def test_promote_cross_workspace(c: cmux) -> None:
    """Drag an inner surface to the outer tab strip of a DIFFERENT workspace → moved there."""
    all_ids = _workspace_ids(c)
    if len(all_ids) < 2:
        # Need a second workspace — create one.
        resp = c._call("workspace.create", {}) or {}
        second_id = resp.get("id") or resp.get("workspace_id")
        _must(bool(second_id), f"workspace.create returned no id: {resp}")
        all_ids = _workspace_ids(c)
    _must(len(all_ids) >= 2, f"need >=2 workspaces; got {len(all_ids)}")

    src_ws_id = all_ids[0]
    dst_ws_id = all_ids[1]

    # Get a surface from the source workspace's first pane.
    panes = (c._call("pane.list", {"workspace_id": src_ws_id}) or {}).get("panes", [])
    _must(len(panes) >= 1, f"source workspace must have at least one pane: {panes}")

    # Ensure source has at least 2 panes so the source workspace doesn't go empty.
    if len(panes) < 2:
        first_surface_id = panes[0].get("selected_surface_id") or (panes[0].get("surface_ids") or [None])[0]
        _must(bool(first_surface_id), f"source pane has no surface: {panes[0]}")
        c._call("surface.create", {
            "workspace_id": src_ws_id,
            "surface_id": first_surface_id,
            "split_orientation": "horizontal",
        })
        panes = (c._call("pane.list", {"workspace_id": src_ws_id}) or {}).get("panes", [])
    _must(len(panes) >= 2, f"source needs >=2 panes; got {len(panes)}")

    surface_id = panes[0].get("selected_surface_id") or (panes[0].get("surface_ids") or [None])[0]
    _must(bool(surface_id), f"source pane has no surface: {panes[0]}")

    before_dst = c.wstab_list(dst_ws_id)
    before_dst_ids = {t["id"] for t in before_dst}

    result = c.drag_surface_to_outer_strip(surface_id=surface_id, target_workspace_id=dst_ws_id)
    _must("error" not in result, f"cross-workspace promote_surface_drop failed: {result}")

    after_dst = c.wstab_list(dst_ws_id)
    _must(
        len(after_dst) == len(before_dst) + 1,
        f"destination wstab count should grow by 1; before={len(before_dst)} after={len(after_dst)}",
    )
    new_wstabs = [t for t in after_dst if t["id"] not in before_dst_ids]
    _must(len(new_wstabs) == 1, f"exactly one new wstab in destination; got {len(new_wstabs)}")
    new_wstab_surfaces = new_wstabs[0].get("surface_ids") or []
    _must(
        surface_id in new_wstab_surfaces,
        f"moved surface {surface_id!r} must live in the new destination wstab; got {new_wstabs[0]}",
    )


def main() -> int:
    with cmux(SOCKET_PATH) as c:
        print("test_promote_same_workspace ...", end=" ", flush=True)
        test_promote_same_workspace(c)
        print("PASS")

        print("test_promote_cross_workspace ...", end=" ", flush=True)
        test_promote_cross_workspace(c)
        print("PASS")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
