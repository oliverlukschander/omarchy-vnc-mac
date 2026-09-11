#!/usr/bin/python3
"""Add or remove the Setup → VNC Mac row in the user Omarchy menu."""

from __future__ import annotations

import sys
from pathlib import Path

from safe_file import atomic_write, die, read_text

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


def _with_row(text: str) -> str:
    if MARKER in text:
        return text
    idx = text.rfind("}")
    if idx == -1:
        return "{\n" + ROW + "}\n"
    return text[:idx] + ROW + text[idx:]


def _without_row(text: str) -> str:
    return "".join(line for line in text.splitlines(keepends=True) if MARKER not in line)


def install() -> None:
    atomic_write(MENU, _with_row(read_text(MENU, missing="{\n}\n")))


def uninstall() -> None:
    text = read_text(MENU, missing="")
    if not text:
        return
    atomic_write(MENU, _without_row(text))


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "install"
    if action == "uninstall":
        uninstall()
    elif action == "install":
        install()
    else:
        die("usage: menu.py [install|uninstall]")
