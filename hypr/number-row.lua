-- Omarchy default workspace binds are SUPER+code:10..19 (XKB keycodes).
-- VNC clients send number-row keysyms, not those keycodes. Bind the
-- keysyms as well. VNC Mac clones these onto Alt for Cmd-as-Alt.
--
-- Shift+1 is keysym "exclam", not "1". Screen Sharing may send "1" with
-- Shift, or the shifted character with or without Shift still in the
-- mod mask. Bind all three so Cmd+Shift+1 moves the window.

local shifted = {
  "exclam",
  "at",
  "numbersign",
  "dollar",
  "percent",
  "asciicircum",
  "ampersand",
  "asterisk",
  "parenleft",
  "parenright",
}

for workspace = 1, 9 do
  local n = tostring(workspace)
  o.bind("SUPER + " .. n, "Switch to workspace " .. n, hl.dsp.focus({ workspace = n }))
  o.bind("SUPER + SHIFT + " .. n, "Move window to workspace " .. n, hl.dsp.window.move({ workspace = n }))
end
o.bind("SUPER + 0", "Switch to workspace 10", hl.dsp.focus({ workspace = "10" }))
o.bind("SUPER + SHIFT + 0", "Move window to workspace 10", hl.dsp.window.move({ workspace = "10" }))

for i, key in ipairs(shifted) do
  local ws = tostring(i)
  o.bind("SUPER + SHIFT + " .. key, "Move window to workspace " .. ws, hl.dsp.window.move({ workspace = ws }))
  o.bind("SUPER + " .. key, "Move window to workspace " .. ws, hl.dsp.window.move({ workspace = ws }))
end
