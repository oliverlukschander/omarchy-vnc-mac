# VNC Mac

Cmd from a Mac VNC client (Screen Sharing) acts as Super on Omarchy 4.

There is no first-party Omarchy plugin for this. macOS Screen Sharing sends
**left Cmd as Alt**, not Super. Hyprland only treats the Windows/Super keycode
as SUPER. This plugin clones every `o.bind` Super shortcut onto Alt so Cmd+Space,
Cmd+Return, Cmd+1, Cmd+W, and the rest fire over VNC.

- Super shortcuts stay Super on the laptop keyboard
- Super→Alt clones apply only to the WayVNC keyboard, so local Alt+Tab etc. stay Omarchy's Alt shortcuts
- Option from Screen Sharing (Meta) is mapped to Alt, so those Alt shortcuts work over VNC too
- Cmd+Shift matches Super+Shift (move window, file manager, browser, …). Screen Sharing sends unshifted keysyms while Shift is held; spare keys keep Cmd+Shift without changing what Shift+/ types (`?`)
- SUPER + ALT chords are not cloned (they would collapse onto Alt-only and collide)
- WayVNC, if installed, gets a keymap that keeps Cmd as Alt_L (the Super→Alt clones are what make Cmd fire Super shortcuts) and maps Option/Meta to Alt. That file must use `//` comments; Lua `--` comments fail to compile and wayvnc then aborts on disconnect. Reconnect after install so WayVNC loads it.

`omarchy plugin add` never runs install hooks, so the mapping is applied by
`install.sh`.

## Install

```sh
omarchy plugin add https://github.com/oliverlukschander/omarchy-vnc-mac.git --enable
~/.config/omarchy/plugins/oliverlukschander.vnc-mac/install.sh
```

`install.sh` hooks `~/.config/hypr/hyprland.lua` (no sudo) so the clone wraps
`o.bind` before Omarchy registers shortcuts (including Super+Shift onto spare
keycodes), writes a Hyprland toggle for number-row workspace binds (VNC sends
`2` instead of `code:11`), and if WayVNC is present installs the VNC keymap.

Click the ⌘ icon in the bar, or *Setup → VNC Mac* in the Omarchy menu, and use
**Install mapping** if you would rather run that from a floating terminal.

Works next to [Mac Option](https://github.com/oliverlukschander/omarchy-mac-option),
[Vi Mode](https://github.com/oliverlukschander/omarchy-vi-mode), and
[Vi Resize](https://github.com/oliverlukschander/omarchy-vi-resize).

## Usage

From a Mac, connect over Tailscale VNC and use Cmd as Super:

| Keys | Result |
| --- | --- |
| Cmd+Space | Omarchy menu |
| Cmd+Return | Terminal |
| Cmd+1 … 0 | Workspaces |
| Cmd+Shift+1 … 0 | Move window to workspace |
| Cmd+Shift+F / B / Return | File manager / browser |
| Cmd+Shift+Tab | Previous workspace |
| Cmd+W | Close window |
| Cmd+C / V / X | Copy / paste / cut |

If Cmd+Space still opens Spotlight, disable that shortcut on the Mac:
**System Settings → Keyboard → Keyboard Shortcuts → Spotlight**. Fullscreen
Screen Sharing does not steal Super, but it does not disable Spotlight either.

## Remove

```sh
~/.config/omarchy/plugins/oliverlukschander.vnc-mac/uninstall.sh
omarchy plugin remove oliverlukschander.vnc-mac
```

Run the uninstaller first. Removing the plugin folder also deletes the
uninstaller.

## License and dependencies

MIT. See [LICENSE](LICENSE).

Optional: [wayvnc](https://github.com/any1/wayvnc) for the VNC keymap. The Super
→ Alt bind clone works without it.

Requires **Omarchy 4** (Quattro shell).
