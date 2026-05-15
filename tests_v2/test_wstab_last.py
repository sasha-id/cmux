#!/usr/bin/env python3
"""v2 regression: wstab.last re-focuses the previously focused workspace tab."""

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
        a = c.wstab_create(workspace_id, title="A")
        b = c.wstab_create(workspace_id, title="B")

        c.wstab_focus(a["id"])
        c.wstab_focus(b["id"])

        c.wstab_last(workspace_id)

        focused = [t for t in c.wstab_list(workspace_id) if t.get("focused")][0]
        _must(focused["id"] == a["id"], f"expected A focused; got {focused['id']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
