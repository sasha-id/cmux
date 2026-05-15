#!/usr/bin/env python3
"""v2 regression: wstab.reorder repositions a workspace tab."""

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
        d = c.wstab_create(workspace_id, title="D")

        c.wstab_reorder(d["id"], before=a["id"])

        order = [t["title"] for t in c.wstab_list(workspace_id) if t["title"] in ("A", "B", "D")]
        _must(order == ["D", "A", "B"], f"expected D A B; got {order}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
