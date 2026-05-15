#!/usr/bin/env python3
"""v2 regression: wstab.create verb appends a workspace tab with a default terminal surface."""

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
        workspaces = c._call("workspace.list", {}) or {}
        wlist = workspaces.get("workspaces") or []
        _must(len(wlist) > 0, "need at least one workspace")
        workspace_id = wlist[0]["id"]

        before = c.wstab_list(workspace_id)
        before_count = len(before)

        result = c.wstab_create(workspace_id, title="Build")
        _must(bool(result.get("id")), f"wstab.create returned no id: {result}")
        _must(result.get("title") == "Build", f"wstab.create returned wrong title: {result}")

        after = c.wstab_list(workspace_id)
        _must(len(after) == before_count + 1, f"wstab.list should grow by 1 (got {len(after) - before_count})")

        new_id = result["id"]
        new_tab = next((t for t in after if t["id"] == new_id), None)
        _must(new_tab is not None, "newly created tab missing from list")
        _must(len(new_tab.get("surface_ids") or []) == 1, f"new tab should seed exactly one surface: {new_tab}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
