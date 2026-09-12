#!/usr/bin/python3
"""Add or remove the Setup → VNC Mac row in the user Omarchy menu."""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from safe_file import atomic_write, die, read_text

_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))
MENU = _CONFIG / "omarchy" / "extensions" / "omarchy-menu.jsonc"
MARKER = '"setup.vnc-mac"'


def _atom(path: str) -> str:
    if not os.path.isabs(path) or ".." in path.split("/"):
        die(f"unsafe plugin path: {path}")
    for c in path:
        if not (c.isalnum() or c in "/._-"):
            die(f"unsafe plugin path: {path}")
    return path


def _row() -> str:
    host = _atom(os.path.join(os.path.dirname(os.path.abspath(__file__)), "menu_host.py"))
    return (
        '  "setup.vnc-mac": {'
        '"icon":"⌘",'
        '"label":"VNC Mac",'
        '"description":"Cmd from a Mac VNC client acts as Super",'
        f'"action":"/usr/bin/python3 -I {host} action \'{{}}\'",'
        f'"checked":"/usr/bin/python3 -I {host} checked"'
        "},\n"
    )


def _with_row(text: str) -> str:
    row = _row()
    if MARKER in text:
        return "".join(line if MARKER not in line else row for line in text.splitlines(keepends=True))
    idx = text.rfind("}")
    if idx == -1:
        return "{\n" + row + "}\n"
    return text[:idx] + row + text[idx:]


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
