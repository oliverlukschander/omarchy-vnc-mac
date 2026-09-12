#!/usr/bin/python3
"""Insert or remove the VNC Mac wrap-bind hook in hyprland.lua."""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from safe_file import die, read_text, atomic_write


def install(hypr: Path, wrap: Path, begin: str, end: str) -> None:
    wrap_s = os.path.abspath(str(wrap))
    if any(c in wrap_s for c in '"\\\n\r'):
        die("illegal wrap path")
    wrap_text = read_text(Path(wrap_s))
    if "function o.bind" not in wrap_text:
        die(f"wrap file does not look like wrap-bind.lua: {wrap_s}")
    text = read_text(hypr)
    block = f"{begin}\npcall(dofile, \"{wrap_s}\")\n{end}\n"
    if begin in text:
        pre, rest = text.split(begin, 1)
        _, post = rest.split(end, 1)
        text = pre + block + post.lstrip("\n")
    else:
        needle = 'require("default.hypr.omarchy")'
        idx = text.find(needle)
        if idx == -1:
            die('Could not find require("default.hypr.omarchy") in hyprland.lua')
        text = text[:idx] + block + "\n" + text[idx:]
    atomic_write(hypr, text)
    print(f"Wrote hook in {hypr}")


def uninstall(hypr: Path, begin: str, end: str) -> None:
    text = read_text(hypr, missing="")
    if not text or begin not in text:
        return
    pre, rest = text.split(begin, 1)
    _, post = rest.split(end, 1)
    atomic_write(hypr, pre + post.lstrip("\n"))


def main(argv: list[str]) -> None:
    if not argv[1:]:
        die("usage: hypr_hook.py install HYPR WRAP BEGIN END | uninstall HYPR BEGIN END")
    action = argv[1]
    if action == "install" and len(argv) == 6:
        install(Path(argv[2]), Path(argv[3]), argv[4], argv[5])
    elif action == "uninstall" and len(argv) == 5:
        uninstall(Path(argv[2]), argv[3], argv[4])
    else:
        die("usage: hypr_hook.py install HYPR WRAP BEGIN END | uninstall HYPR BEGIN END")


if __name__ == "__main__":
    main(sys.argv)
