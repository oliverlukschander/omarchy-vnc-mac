-- macOS Screen Sharing: left Cmd arrives as Alt_L and must stay Alt_L in
-- the WayVNC keymap (a Super/Meta remap makes Cmd look like Super+Alt and
-- matches neither bind). Clone Super shortcuts onto Alt *only* for the
-- WayVNC virtual keyboard so the laptop's real Alt (Alt+Tab, etc.) stays
-- intact.
--
-- Skip Super+Alt chords: they would collapse onto Alt-only and collide.
--
-- Cmd+Shift is a second path. Screen Sharing sends the unshifted keysym
-- (XK_f, XK_1) while Shift is held. WayVNC then clears every modifier to
-- reach level 0, so Cmd+Shift+F arrives as Alt+F. Spare keys in macvnc
-- hold those unshifted keysyms on the shift level only; rewrite Shift
-- binds onto those keycodes so the chord still fires. Real keys stay US,
-- so Shift+/ still types "?".

rawset(_G, "_oliverlukschander_vnc_mac_bound", nil)

if rawget(_G, "_oliverlukschander_vnc_mac_require") == nil then
  rawset(_G, "_oliverlukschander_vnc_mac_require", require)
end

local orig_require = rawget(_G, "_oliverlukschander_vnc_mac_require")
local VNC_DEVICES = { "hl-virtual-keyboard-wayvnc" }

-- Spare XKB keys <I216>..<I256> and <I360>..<I366> in xkb/symbols/macvnc.
-- the real key → spare keycode. Keep in sync with that file.
local SPARE = {
  { 216, "1", 10 },
  { 217, "2", 11 },
  { 218, "3", 12 },
  { 219, "4", 13 },
  { 220, "5", 14 },
  { 221, "6", 15 },
  { 222, "7", 16 },
  { 223, "8", 17 },
  { 224, "9", 18 },
  { 225, "0", 19 },
  { 226, "minus", 20 },
  { 227, "equal", 21 },
  { 228, "q", 24 },
  { 229, "w", 25 },
  { 230, "e", 26 },
  { 231, "r", 27 },
  { 232, "t", 28 },
  { 233, "y", 29 },
  { 234, "u", 30 },
  { 235, "i", 31 },
  { 236, "o", 32 },
  { 237, "p", 33 },
  { 238, "bracketleft", 34 },
  { 239, "bracketright", 35 },
  { 240, "backslash", 51 },
  { 241, "a", 38 },
  { 242, "s", 39 },
  { 243, "d", 40 },
  { 244, "f", 41 },
  { 245, "g", 42 },
  { 246, "h", 43 },
  { 247, "j", 44 },
  { 248, "k", 45 },
  { 249, "l", 46 },
  { 250, "semicolon", 47 },
  { 251, "apostrophe", 48 },
  { 252, "z", 52 },
  { 253, "x", 53 },
  { 254, "c", 54 },
  { 255, "v", 55 },
  { 256, "b", 56 },
  -- evdev has no <I257>..<I359>; continue on <I360>+.
  { 360, "n", 57 },
  { 361, "m", 58 },
  { 362, "comma", 59 },
  { 363, "period", 60 },
  { 364, "slash", 61 },
  { 365, "grave", 49 },
  { 366, "tab", 23 },
}

local DUMMY = {}
for _, row in ipairs(SPARE) do
  local dummy, name, real = row[1], row[2], row[3]
  DUMMY[name] = dummy
  DUMMY["code:" .. tostring(real)] = dummy
end

local function tokens(keys)
  local t = {}
  for raw in string.gmatch(keys, "[^%+]+") do
    local part = raw:match("^%s*(.-)%s*$")
    if part and part ~= "" then
      t[#t + 1] = part
    end
  end
  return t
end

local function is_alt_token(part)
  local u = part:upper()
  return u == "ALT" or u == "ALT_L" or u == "ALT_R" or u == "MOD1"
end

local function is_shift_token(part)
  return part:upper() == "SHIFT"
end

local function super_to_alt(keys)
  if type(keys) ~= "string" then
    return nil
  end
  if not keys:upper():find("SUPER", 1, true) then
    return nil
  end

  local t = tokens(keys)
  for _, part in ipairs(t) do
    if is_alt_token(part) then
      return nil
    end
  end

  local out = {}
  for _, part in ipairs(t) do
    if part:upper() == "SUPER" then
      out[#out + 1] = "ALT"
    else
      out[#out + 1] = part
    end
  end
  return table.concat(out, " + ")
end

local function shift_to_dummy(keys)
  if type(keys) ~= "string" then
    return nil
  end

  local t = tokens(keys)
  local saw_shift = false
  for _, part in ipairs(t) do
    if is_shift_token(part) then
      saw_shift = true
    end
  end
  if not saw_shift then
    return nil
  end

  local out = {}
  local replaced = false
  for _, part in ipairs(t) do
    local dummy = DUMMY[part:lower()]
    if dummy then
      out[#out + 1] = "code:" .. tostring(dummy)
      replaced = true
    else
      out[#out + 1] = part
    end
  end
  if not replaced then
    return nil
  end
  return table.concat(out, " + ")
end

local function tab_iso_alias(keys)
  if type(keys) ~= "string" then
    return nil
  end

  local t = tokens(keys)
  local saw_shift, saw_tab = false, false
  for _, part in ipairs(t) do
    local u = part:upper()
    if u == "SHIFT" then
      saw_shift = true
    elseif u == "TAB" then
      saw_tab = true
    end
  end
  if not (saw_shift and saw_tab) then
    return nil
  end

  local out = {}
  for _, part in ipairs(t) do
    if part:upper() == "TAB" then
      out[#out + 1] = "ISO_Left_Tab"
    else
      out[#out + 1] = part
    end
  end
  return table.concat(out, " + ")
end

local function with_vnc_device(options)
  local opts = {}
  if type(options) == "table" then
    for k, v in pairs(options) do
      opts[k] = v
    end
  end
  opts.devices = VNC_DEVICES
  return opts
end

function require(mod)
  local result = orig_require(mod)
  if mod == "default.hypr.helpers" and o and type(o.bind) == "function" and not rawget(_G, "_oliverlukschander_vnc_mac_bound") then
    rawset(_G, "_oliverlukschander_vnc_mac_bound", true)
    local orig_bind = o.bind
    function o.bind(keys, description, dispatcher, options)
      orig_bind(keys, description, dispatcher, options)

      local vnc = with_vnc_device(options)
      local alt = super_to_alt(keys)
      if alt then
        orig_bind(alt, description, dispatcher, vnc)
      end

      -- Super+Alt chords are not cloned; spare keys would not help there.
      if alt then
        local dummy = shift_to_dummy(keys)
        if dummy then
          orig_bind(dummy, description, dispatcher, vnc)
          local dummy_alt = super_to_alt(dummy)
          if dummy_alt then
            orig_bind(dummy_alt, description, dispatcher, vnc)
          end
        end

        local iso = tab_iso_alias(keys)
        if iso then
          orig_bind(iso, description, dispatcher, vnc)
          local iso_alt = super_to_alt(iso)
          if iso_alt then
            orig_bind(iso_alt, description, dispatcher, vnc)
          end
        end
      end
    end
  end
  return result
end
