#!/usr/bin/bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON=/usr/bin/python3
HYPRCTL=/usr/bin/hyprctl
SYSTEMCTL=/usr/bin/systemctl
OMARCHY=/usr/bin/omarchy
HYPR_LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
BEGIN="-- BEGIN oliverlukschander.vnc-mac"
END="-- END oliverlukschander.vnc-mac"
TOGGLE_DST="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr/oliverlukschander-vnc-mac.lua"
XKB_DST="${XDG_CONFIG_HOME:-$HOME/.config}/xkb/symbols/macvnc"
WAYVNC_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/wayvnc/config"

echo "Removing Omarchy VNC Mac mapping"

if [[ ! -x $PYTHON ]]; then
  echo "Missing $PYTHON" >&2
  exit 1
fi

run() {
  local timeout=$1 max=$2
  shift 2
  "$PYTHON" -I "$PLUGIN_DIR/scripts/run.py" --timeout "$timeout" --max-stdout "$max" --max-stderr "$max" -- "$@"
}

py() {
  run 15 1048576 "$PYTHON" -I "$@"
}

py "$PLUGIN_DIR/scripts/safe_file.py" remove "$TOGGLE_DST"
if [[ -f $HYPR_LUA ]]; then
  py "$PLUGIN_DIR/scripts/hypr_hook.py" uninstall "$HYPR_LUA" "$BEGIN" "$END"
fi
py "$PLUGIN_DIR/scripts/safe_file.py" remove "$XKB_DST"

if [[ -f $WAYVNC_CFG ]]; then
  py "$PLUGIN_DIR/scripts/wayvnc_cfg.py" uninstall "$WAYVNC_CFG"
  if [[ -x $SYSTEMCTL ]]; then
    run 8 65536 "$SYSTEMCTL" --user restart wayvnc.service >/dev/null || true
  fi
fi

if [[ -x $HYPRCTL ]]; then
  run 5 65536 "$HYPRCTL" reload >/dev/null || true
fi

py "$PLUGIN_DIR/scripts/menu.py" uninstall
if [[ -x $OMARCHY ]]; then
  run 5 65536 "$OMARCHY" menu refresh >/dev/null || true
fi

echo "VNC Mac mapping removed. Super shortcuts are unchanged; Cmd-as-Alt clones are gone."
