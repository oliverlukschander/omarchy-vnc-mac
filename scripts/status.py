#!/usr/bin/python3
"""Bounded status probe for the VNC Mac bar widget."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from run import run
from safe_file import read_text

HYPRCTL = "/usr/bin/hyprctl"
TIMEOUT_SEC = 2
MAX_STDOUT = 256 * 1024
MAX_STDERR = 64 * 1024


def _exists_regular(path: Path) -> bool:
    try:
        read_text(path)
        return True
    except SystemExit:
        return False
    except OSError:
        return False


def _hyprctl_binds() -> str:
    code, stdout, _stderr = run(
        [HYPRCTL, "binds", "-j"],
        timeout=TIMEOUT_SEC,
        max_stdout=MAX_STDOUT,
        max_stderr=MAX_STDERR,
    )
    if code != 0:
        return ""
    try:
        binds = json.loads(stdout.decode())
    except (ValueError, UnicodeDecodeError):
        return ""
    if not isinstance(binds, list):
        return ""
    for bind in binds:
        if not isinstance(bind, dict):
            continue
        if bind.get("modmask") == 8 and bind.get("key") == "SPACE":
            desc = bind.get("description") or ""
            return desc if isinstance(desc, str) else ""
    return ""


def main() -> None:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))
    state_home = Path(os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local/state"))
    hypr = config_home / "hypr" / "hyprland.lua"
    toggle = state_home / "omarchy" / "toggles" / "hypr" / "oliverlukschander-vnc-mac.lua"
    wayvnc = config_home / "wayvnc" / "config"

    hook_present = False
    try:
        text = read_text(hypr)
        if "oliverlukschander.vnc-mac" in text:
            hook_present = True
    except SystemExit:
        pass
    if not hook_present and _exists_regular(toggle):
        hook_present = True

    desc = _hyprctl_binds()
    binds_active = "Omarchy menu" in desc

    wayvnc_mac = False
    try:
        cfg = read_text(wayvnc)
        wayvnc_mac = any(line.startswith("xkb_layout=macvnc") for line in cfg.splitlines())
    except SystemExit:
        pass

    sys.stdout.write(
        json.dumps(
            {
                "hookPresent": hook_present,
                "bindsActive": binds_active,
                "wayvncMac": wayvnc_mac,
            },
            separators=(",", ":"),
        )
        + "\n"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.stdout.write('{"hookPresent":false,"bindsActive":false,"wayvncMac":false}\n')
        raise SystemExit(0)
