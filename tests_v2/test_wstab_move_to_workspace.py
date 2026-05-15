#!/usr/bin/env python3
"""v2 regression: wstab.move_to_workspace preserves surface UUIDs across workspaces."""

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
        wlist = (c._call("workspace.list", {}) or {})["workspaces"]
        _must(len(wlist) >= 2, f"need at least 2 workspaces for this test; got {len(wlist)}")
        w1, w2 = wlist[0]["id"], wlist[1]["id"]

        tab = c.wstab_create(w1, title="Movable")
        before = c.wstab_list(w1)
        tab_meta = next(t for t in before if t["id"] == tab["id"])
        original_surface_ids = list(tab_meta.get("surface_ids") or [])
        _must(len(original_surface_ids) >= 1, "tab should have at least one surface")

        c.wstab_move_to_workspace(tab["id"], w2)

        after_src = c.wstab_list(w1)
        after_dst = c.wstab_list(w2)
        _must(not any(t["id"] == tab["id"] for t in after_src), "tab should be removed from source")
        moved = next((t for t in after_dst if t["id"] == tab["id"]), None)
        _must(moved is not None, "tab should appear in destination")
        _must(set(moved.get("surface_ids") or []) == set(original_surface_ids),
              f"surface UUIDs must be preserved; before={original_surface_ids} after={moved.get('surface_ids')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
