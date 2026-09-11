-- Omarchy default workspace binds are SUPER+code:10..19 (XKB keycodes).
-- VNC clients often send the "2" key as keysym 2. Bind the number-row
-- keysyms as well. VNC Mac clones these onto Alt for Cmd-as-Alt.

for workspace = 1, 9 do
  local n = tostring(workspace)
  o.bind("SUPER + " .. n, "Switch to workspace " .. n, hl.dsp.focus({ workspace = n }))
end
o.bind("SUPER + 0", "Switch to workspace 10", hl.dsp.focus({ workspace = "10" }))
