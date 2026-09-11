#!/usr/bin/env bash
set -euo pipefail

hypr="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
toggle="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr/oliverlukschander-vnc-mac.lua"
hook_present=false
binds_active=false
wayvnc_mac=false

if [[ -f $hypr ]] && grep -qF "oliverlukschander.vnc-mac" "$hypr"; then
  hook_present=true
fi
if [[ -f $toggle ]]; then
  hook_present=true
fi

if command -v hyprctl >/dev/null && command -v python3 >/dev/null; then
  desc=$(hyprctl binds -j 2>/dev/null | python3 -c '
import json, sys
try:
    binds = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
for bind in binds:
    if bind.get("modmask") == 8 and bind.get("key") == "SPACE":
        print(bind.get("description") or "")
        break
' || true)
  if [[ $desc == *"Omarchy menu"* ]]; then
    binds_active=true
  fi
fi

if grep -q '^xkb_layout=macvnc' "${XDG_CONFIG_HOME:-$HOME/.config}/wayvnc/config" 2>/dev/null; then
  wayvnc_mac=true
fi

printf '{"hookPresent":%s,"bindsActive":%s,"wayvncMac":%s}\n' \
  "$hook_present" "$binds_active" "$wayvnc_mac"
