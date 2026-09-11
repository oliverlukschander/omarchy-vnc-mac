#!/usr/bin/env python3
"""Add or remove the Setup → VNC Mac row in the user Omarchy menu."""

from __future__ import annotations

import sys
from pathlib import Path

MENU = Path.home() / ".config/omarchy/extensions/omarchy-menu.jsonc"
MARKER = '"setup.vnc-mac"'
ROW = (
    '  "setup.vnc-mac": {'
    '"icon":"⌘",'
    '"label":"VNC Mac",'
    '"description":"Cmd from a Mac VNC client acts as Super",'
    '"action":"omarchy-shell shell summon oliverlukschander.vnc-mac \'{}\'",'
    '"checked":"grep -qF oliverlukschander.vnc-mac ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"'
    "},\n"
)


def install() -> None:
    MENU.parent.mkdir(parents=True, exist_ok=True)
    text = MENU.read_text() if MENU.exists() else "{\n}\n"
    if MARKER in text:
        lines = text.splitlines(keepends=True)
        text = "".join(line if MARKER not in line else ROW for line in lines)
    else:
        idx = text.rfind("}")
        if idx == -1:
            text = "{\n" + ROW + "}\n"
        else:
            text = text[:idx] + ROW + text[idx:]
    MENU.write_text(text)


def uninstall() -> None:
    if not MENU.exists():
        return
    lines = MENU.read_text().splitlines(keepends=True)
    MENU.write_text("".join(line for line in lines if MARKER not in line))


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "install"
    if action == "uninstall":
        uninstall()
    else:
        install()
