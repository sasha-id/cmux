#!/usr/bin/env python3
"""v2 regression: wstab.focus selects the target tab and is reflected in wstab.list."""

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
        _ = c.wstab_create(workspace_id, title="A")
        tab_b = c.wstab_create(workspace_id, title="B")

        c.wstab_focus(tab_b["id"])

        focused = [t for t in c.wstab_list(workspace_id) if t.get("focused")]
        _must(len(focused) == 1, f"exactly one tab should be focused; got {focused}")
        _must(focused[0]["id"] == tab_b["id"], f"expected B focused; got {focused[0]['id']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
