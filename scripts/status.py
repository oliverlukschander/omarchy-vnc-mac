#!/usr/bin/python3
"""Bounded status probe for the VNC Mac bar widget."""

from __future__ import annotations

import json
import os
import select
import signal
import subprocess
import sys
import time
from pathlib import Path

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


def _ingest(fd, buf: bytearray, cap: int) -> tuple[bool, bool]:
    """Read one chunk. Returns (eof, overflow)."""
    try:
        chunk = os.read(fd.fileno(), 4096)
    except OSError:
        return True, False
    if not chunk:
        return True, False
    room = cap - len(buf)
    if room <= 0:
        return False, True
    if len(chunk) > room:
        buf.extend(chunk[:room])
        return False, True
    buf.extend(chunk)
    return False, False


def _kill_group(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    except OSError:
        try:
            proc.kill()
        except OSError:
            pass


def _hyprctl_binds() -> str:
    if not os.path.isfile(HYPRCTL) or not os.access(HYPRCTL, os.X_OK):
        return ""
    try:
        proc = subprocess.Popen(
            [HYPRCTL, "binds", "-j"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd="/",
            env={"PATH": "/usr/bin:/bin", "HOME": os.environ.get("HOME", "")},
            start_new_session=True,
        )
    except OSError:
        return ""
    stdout = bytearray()
    stderr = bytearray()
    stdout_eof = False
    stderr_eof = False
    truncated = False
    timed_out = False
    deadline = time.monotonic() + TIMEOUT_SEC
    try:
        while not (stdout_eof and stderr_eof):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                timed_out = True
                break
            pipes = []
            if not stdout_eof and proc.stdout is not None:
                pipes.append(proc.stdout)
            if not stderr_eof and proc.stderr is not None:
                pipes.append(proc.stderr)
            if not pipes:
                break
            ready, _, _ = select.select(pipes, [], [], min(remaining, 0.05))
            if not ready and proc.poll() is not None:
                ready, _, _ = select.select(pipes, [], [], 0)
                if not ready:
                    break
            for fd in ready:
                if fd is proc.stdout:
                    eof, overflow = _ingest(fd, stdout, MAX_STDOUT)
                    stdout_eof = stdout_eof or eof
                    truncated = truncated or overflow
                else:
                    eof, overflow = _ingest(fd, stderr, MAX_STDERR)
                    stderr_eof = stderr_eof or eof
                    truncated = truncated or overflow
            if truncated:
                break
    finally:
        if truncated or timed_out or proc.poll() is None:
            _kill_group(proc)
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            _kill_group(proc)
            proc.wait(timeout=1)
        for fd in (proc.stdout, proc.stderr):
            if fd is not None:
                fd.close()
    if timed_out or truncated:
        return ""
    try:
        binds = json.loads(bytes(stdout).decode())
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
