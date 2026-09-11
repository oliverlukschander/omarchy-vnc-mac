#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
BEGIN="-- BEGIN oliverlukschander.vnc-mac"
END="-- END oliverlukschander.vnc-mac"
TOGGLE_DST="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr/oliverlukschander-vnc-mac.lua"
XKB_DST="${XDG_CONFIG_HOME:-$HOME/.config}/xkb/symbols/macvnc"

echo "Removing Omarchy VNC Mac mapping"

rm -f "$TOGGLE_DST"

if [[ -f $HYPR_LUA ]] && grep -qF "$BEGIN" "$HYPR_LUA"; then
  python3 - "$HYPR_LUA" "$BEGIN" "$END" <<'PY'
from pathlib import Path
import sys
p, begin, end = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = p.read_text()
if begin not in text:
    raise SystemExit(0)
pre, rest = text.split(begin, 1)
_, post = rest.split(end, 1)
p.write_text(pre + post.lstrip("\n"))
PY
fi

rm -f "$XKB_DST"

if [[ -f ${XDG_CONFIG_HOME:-$HOME/.config}/wayvnc/config ]]; then
  python3 - "${XDG_CONFIG_HOME:-$HOME/.config}/wayvnc/config" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
lines = p.read_text().splitlines()
out = []
for line in lines:
    if line.startswith("xkb_layout="):
        out.append("xkb_layout=us")
    elif line.startswith("xkb_variant="):
        out.append("xkb_variant=mac")
    elif line.startswith("xkb_model="):
        out.append("xkb_model=pc104")
    elif line.startswith("xkb_options="):
        continue
    else:
        out.append(line)
if not any(l.startswith("xkb_variant=") for l in out):
    out.append("xkb_variant=mac")
p.write_text("\n".join(out) + "\n")
PY
  systemctl --user restart wayvnc.service >/dev/null 2>&1 || true
fi

if command -v hyprctl >/dev/null; then
  hyprctl reload >/dev/null || true
fi

python3 "$PLUGIN_DIR/scripts/menu.py" uninstall
omarchy menu refresh >/dev/null 2>&1 || true

echo "VNC Mac mapping removed. Super shortcuts are unchanged; Cmd-as-Alt clones are gone."
