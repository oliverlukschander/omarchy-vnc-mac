#!/usr/bin/python3
"""Omarchy-menu checked/action helper. Invoked as an absolute python3 -I command."""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pathlib import Path

from run import closed_env
from safe_file import read_text

PLUGIN_ID = "oliverlukschander.vnc-mac"
OMARCHY_SHELL = "/usr/bin/omarchy-shell"


def _config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))


def checked() -> int:
    hypr = _config_home() / "hypr" / "hyprland.lua"
    try:
        text = read_text(hypr)
    except SystemExit:
        return 1
    return 0 if PLUGIN_ID in text else 1


def action(payload: str) -> None:
    if "\x00" in payload:
        raise SystemExit("illegal payload")
    if not os.path.isfile(OMARCHY_SHELL) or not os.access(OMARCHY_SHELL, os.X_OK):
        raise SystemExit(f"missing {OMARCHY_SHELL}")
    os.execve(
        OMARCHY_SHELL,
        [OMARCHY_SHELL, "shell", "summon", PLUGIN_ID, payload],
        closed_env(),
    )


def main(argv: list[str]) -> None:
    if len(argv) >= 2 and argv[1] == "checked":
        raise SystemExit(checked())
    if len(argv) >= 2 and argv[1] == "action":
        payload = argv[2] if len(argv) > 2 else "{}"
        action(payload)
        raise SystemExit("execve failed")
    raise SystemExit("usage: menu_host.py checked | action [payload]")


if __name__ == "__main__":
    main(sys.argv)
