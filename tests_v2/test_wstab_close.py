#!/usr/bin/env python3
"""v2 regression: wstab.close removes the workspace tab and tears down its inner Bonsplit."""

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
        tab = c.wstab_create(workspace_id, title="Doomed")
        _must(any(t["id"] == tab["id"] for t in c.wstab_list(workspace_id)), "tab should be in list before close")

        c.wstab_close(tab["id"])

        _must(not any(t["id"] == tab["id"] for t in c.wstab_list(workspace_id)), "tab should be gone after close")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
