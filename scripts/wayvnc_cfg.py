#!/usr/bin/python3
"""Set or restore xkb_* keys in the user WayVNC config."""

from __future__ import annotations

import sys
from pathlib import Path

from safe_file import die, read_text, atomic_write


def _rewrite(path: Path, layout: str, variant: str | None, drop_options: bool) -> None:
    text = read_text(path)
    lines = text.splitlines()
    out: list[str] = []
    seen_layout = False
    seen_model = False
    seen_variant = False
    for line in lines:
        if line.startswith("xkb_layout="):
            out.append(f"xkb_layout={layout}")
            seen_layout = True
        elif line.startswith("xkb_model="):
            out.append("xkb_model=pc104")
            seen_model = True
        elif line.startswith("xkb_variant="):
            if variant is None:
                continue
            out.append(f"xkb_variant={variant}")
            seen_variant = True
        elif line.startswith("xkb_options=") and drop_options:
            continue
        else:
            out.append(line)
    if not seen_layout:
        out.append(f"xkb_layout={layout}")
    if not seen_model:
        out.append("xkb_model=pc104")
    if variant is not None and not seen_variant:
        out.append(f"xkb_variant={variant}")
    atomic_write(path, "\n".join(out) + "\n")
    print(f"Updated {path} (xkb_layout={layout})")


def main(argv: list[str]) -> None:
    if len(argv) < 3:
        die("usage: wayvnc_cfg.py install CFG true|false | uninstall CFG")
    action = argv[1]
    cfg = Path(argv[2])
    if action == "install" and len(argv) == 4:
        use_macvnc = argv[3] == "true"
        layout = "macvnc" if use_macvnc else "us"
        _rewrite(cfg, layout, variant=None, drop_options=True)
    elif action == "uninstall" and len(argv) == 3:
        _rewrite(cfg, "us", variant="mac", drop_options=True)
    else:
        die("usage: wayvnc_cfg.py install CFG true|false | uninstall CFG")


if __name__ == "__main__":
    main(sys.argv)
