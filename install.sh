#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAP_SRC="$PLUGIN_DIR/hypr/wrap-bind.lua"
NUMBER_SRC="$PLUGIN_DIR/hypr/number-row.lua"
HYPR_LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
BEGIN="-- BEGIN oliverlukschander.vnc-mac"
END="-- END oliverlukschander.vnc-mac"
TOGGLE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr"
TOGGLE_DST="$TOGGLE_DIR/oliverlukschander-vnc-mac.lua"
XKB_SRC="$PLUGIN_DIR/xkb/symbols/macvnc"
XKB_DST="${XDG_CONFIG_HOME:-$HOME/.config}/xkb/symbols/macvnc"
WAYVNC_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/wayvnc/config"

echo "Omarchy VNC Mac"
echo "Cmd from macOS Screen Sharing fires the same shortcuts as Super."
echo

if [[ ! -f $WRAP_SRC ]]; then
  echo "Missing $WRAP_SRC" >&2
  exit 1
fi
if [[ ! -f $NUMBER_SRC ]]; then
  echo "Missing $NUMBER_SRC" >&2
  exit 1
fi
if [[ ! -f $HYPR_LUA ]]; then
  echo "Missing $HYPR_LUA" >&2
  exit 1
fi

insert_hypr_hook() {
  python3 - "$HYPR_LUA" "$WRAP_SRC" "$BEGIN" "$END" <<'PY'
from pathlib import Path
import sys

hypr = Path(sys.argv[1])
wrap = Path(sys.argv[2])
begin = sys.argv[3]
end = sys.argv[4]
text = hypr.read_text()
block = (
    f"{begin}\n"
    f'pcall(dofile, "{wrap}")\n'
    f"{end}\n"
)
if begin in text:
    pre, rest = text.split(begin, 1)
    _, post = rest.split(end, 1)
    post = post.lstrip("\n")
    text = pre + block + post
else:
    needle = 'require("default.hypr.omarchy")'
    idx = text.find(needle)
    if idx == -1:
        sys.exit("Could not find require(\"default.hypr.omarchy\") in hyprland.lua")
    text = text[:idx] + block + "\n" + text[idx:]
hypr.write_text(text)
print(f"Wrote hook in {hypr}")
PY
}

insert_hypr_hook

mkdir -p "$TOGGLE_DIR"
install -m 644 "$NUMBER_SRC" "$TOGGLE_DST"
echo "Wrote $TOGGLE_DST"

mkdir -p "$(dirname "$XKB_DST")"
install -m 644 "$XKB_SRC" "$XKB_DST"
echo "Wrote $XKB_DST"

macvnc_ok=false
if command -v xkbcli >/dev/null; then
  if xkbcli compile-keymap --layout macvnc --model pc104 >/dev/null; then
    macvnc_ok=true
  else
    echo "macvnc keymap failed to compile; WayVNC will keep xkb_layout=us" >&2
    echo "A bad keymap makes wayvnc abort when a client disconnects." >&2
  fi
else
  echo "xkbcli not found; not pointing WayVNC at macvnc" >&2
fi

if [[ -f $WAYVNC_CFG ]]; then
  python3 - "$WAYVNC_CFG" "$macvnc_ok" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
use_macvnc = sys.argv[2] == "true"
layout = "macvnc" if use_macvnc else "us"
lines = p.read_text().splitlines()
out, seen_layout, seen_model = [], False, False
for line in lines:
    if line.startswith("xkb_layout="):
        out.append(f"xkb_layout={layout}")
        seen_layout = True
    elif line.startswith("xkb_model="):
        out.append("xkb_model=pc104")
        seen_model = True
    elif line.startswith("xkb_variant="):
        continue
    elif line.startswith("xkb_options="):
        continue
    else:
        out.append(line)
if not seen_layout:
    out.append(f"xkb_layout={layout}")
if not seen_model:
    out.append("xkb_model=pc104")
p.write_text("\n".join(out) + "\n")
print(f"Updated {p} (xkb_layout={layout})")
PY
  systemctl --user restart wayvnc.service >/dev/null 2>&1 || true
fi

if command -v hyprctl >/dev/null; then
  hyprctl reload >/dev/null
  errors=$(hyprctl configerrors 2>/dev/null || true)
  if [[ -n ${errors//[[:space:]]/} ]]; then
    echo "Hyprland config errors:" >&2
    echo "$errors" >&2
  fi
fi

python3 "$PLUGIN_DIR/scripts/menu.py" install
omarchy menu refresh >/dev/null 2>&1 || true

echo
echo "Ready. From a Mac VNC client, left Cmd is Super:"
echo "  Cmd+Space    menu"
echo "  Cmd+Return   terminal"
echo "  Cmd+1..0     workspaces"
echo "  Cmd+W        close window"
echo
echo "If Cmd+Space still opens Spotlight, disable that shortcut on the Mac:"
echo "  System Settings → Keyboard → Keyboard Shortcuts → Spotlight"
