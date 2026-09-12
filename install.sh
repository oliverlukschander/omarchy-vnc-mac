#!/usr/bin/bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON=/usr/bin/python3
HYPRCTL=/usr/bin/hyprctl
XKBCLI=/usr/bin/xkbcli
SYSTEMCTL=/usr/bin/systemctl
OMARCHY=/usr/bin/omarchy
WRAP_SRC="$PLUGIN_DIR/hypr/wrap-bind.lua"
NUMBER_SRC="$PLUGIN_DIR/hypr/number-row.lua"
HYPR_LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
BEGIN="-- BEGIN oliverlukschander.vnc-mac"
END="-- END oliverlukschander.vnc-mac"
TOGGLE_DST="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr/oliverlukschander-vnc-mac.lua"
XKB_SRC="$PLUGIN_DIR/xkb/symbols/macvnc"
XKB_DST="${XDG_CONFIG_HOME:-$HOME/.config}/xkb/symbols/macvnc"
WAYVNC_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/wayvnc/config"

echo "Omarchy VNC Mac"
echo "Cmd from macOS Screen Sharing fires the same shortcuts as Super."
echo

if [[ ! -x $PYTHON ]]; then
  echo "Missing $PYTHON" >&2
  exit 1
fi
for f in "$WRAP_SRC" "$NUMBER_SRC" "$XKB_SRC" "$HYPR_LUA"; do
  if [[ ! -f $f ]]; then
    echo "Missing $f" >&2
    exit 1
  fi
done

run() {
  local timeout=$1 max=$2
  shift 2
  "$PYTHON" -I "$PLUGIN_DIR/scripts/run.py" --timeout "$timeout" --max-stdout "$max" --max-stderr "$max" -- "$@"
}

py() {
  run 15 1048576 "$PYTHON" -I "$@"
}

py "$PLUGIN_DIR/scripts/hypr_hook.py" install "$HYPR_LUA" "$WRAP_SRC" "$BEGIN" "$END"
py "$PLUGIN_DIR/scripts/safe_file.py" copy "$NUMBER_SRC" "$TOGGLE_DST"
echo "Wrote $TOGGLE_DST"
py "$PLUGIN_DIR/scripts/safe_file.py" copy "$XKB_SRC" "$XKB_DST"
echo "Wrote $XKB_DST"

macvnc_ok=false
if [[ -x $XKBCLI ]]; then
  if run 5 262144 "$XKBCLI" compile-keymap --layout macvnc --model pc104 >/dev/null; then
    macvnc_ok=true
  else
    echo "macvnc keymap failed to compile; WayVNC will keep xkb_layout=us" >&2
    echo "A bad keymap makes wayvnc abort when a client disconnects." >&2
  fi
else
  echo "xkbcli not found; not pointing WayVNC at macvnc" >&2
fi

if [[ -f $WAYVNC_CFG ]]; then
  py "$PLUGIN_DIR/scripts/wayvnc_cfg.py" install "$WAYVNC_CFG" "$macvnc_ok"
  if [[ -x $SYSTEMCTL ]]; then
    run 8 65536 "$SYSTEMCTL" --user restart wayvnc.service >/dev/null || true
  fi
fi

if [[ -x $HYPRCTL ]]; then
  run 5 65536 "$HYPRCTL" reload >/dev/null
  errors=$(run 5 65536 "$HYPRCTL" configerrors || true)
  if [[ -n ${errors//[[:space:]]/} ]]; then
    echo "Hyprland config errors:" >&2
    echo "$errors" >&2
  fi
fi

py "$PLUGIN_DIR/scripts/menu.py" install
if [[ -x $OMARCHY ]]; then
  run 5 65536 "$OMARCHY" menu refresh >/dev/null || true
fi

echo
echo "Ready. From a Mac VNC client, left Cmd is Super:"
echo "  Cmd+Space    menu"
echo "  Cmd+Return   terminal"
echo "  Cmd+1..0        workspaces"
echo "  Cmd+Shift+1..0  move window to workspace"
echo "  Cmd+Shift+F     file manager"
echo "  Cmd+W           close window"
echo
echo "If Cmd+Space still opens Spotlight, disable that shortcut on the Mac:"
echo "  System Settings → Keyboard → Keyboard Shortcuts → Spotlight"
echo
echo "Keymap changes need a WayVNC restart; reconnect the Mac VNC client."
