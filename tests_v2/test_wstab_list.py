#!/usr/bin/env python3
"""v2 regression: wstab.list returns id/title/surface_ids/focused for each workspace tab."""

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
        tab_a = c.wstab_create(workspace_id, title="A")
        tab_b = c.wstab_create(workspace_id, title="B")
        c.wstab_focus(tab_a["id"])

        tabs = c.wstab_list(workspace_id)
        by_id = {t["id"]: t for t in tabs}
        _must(by_id[tab_a["id"]].get("focused") is True, "A should be focused")
        _must(by_id[tab_b["id"]].get("focused") is False, "B should not be focused")
        _must(all("surface_ids" in t for t in tabs), "every tab carries surface_ids")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
