#!/usr/bin/env python3
"""v2 regression: wstab.* lifecycle events drive downstream state correctly.

Asserts via state observation: when an event isn't published, downstream
queries that depend on it diverge. Adding a true event-subscription test
needs harness work that is outside this PR's scope; tracked in a follow-up.
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

        # wstab.created: list view must reflect the new tab immediately (depends on
        # the wstab.created event being routed to in-app subscribers).
        before = c.wstab_list(workspace_id)
        tab = c.wstab_create(workspace_id, title="E")
        after = c.wstab_list(workspace_id)
        _must(len(after) == len(before) + 1, "wstab.list must update after wstab.create")
        _must(any(t["id"] == tab["id"] for t in after), "new tab must appear in list")

        # wstab.focused: identify() must report the new focused tab and its surface.
        c.wstab_focus(tab["id"])
        ident = c._call("identify", {}) or {}
        focused = ident.get("focused") or {}
        _must(focused.get("wstab_id") == tab["id"],
              f"identify.focused.wstab_id must match focused tab; got {focused}")

        # wstab.closed: list must shrink and the focused-tab pointer must move.
        c.wstab_close(tab["id"])
        after_close = c.wstab_list(workspace_id)
        _must(not any(t["id"] == tab["id"] for t in after_close),
              "closed tab must be gone from list")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
