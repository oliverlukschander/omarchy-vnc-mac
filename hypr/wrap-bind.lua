-- macOS Screen Sharing: left Cmd arrives as Alt_L and must stay Alt_L in
-- the WayVNC keymap (a Super/Meta remap makes Cmd look like Super+Alt and
-- matches neither bind). Clone Super shortcuts onto Alt *only* for the
-- WayVNC virtual keyboard so the laptop's real Alt (Alt+Tab, etc.) stays
-- intact.
--
-- Skip Super+Alt chords: they would collapse onto Alt-only and collide.

rawset(_G, "_oliverlukschander_vnc_mac_bound", nil)

if rawget(_G, "_oliverlukschander_vnc_mac_require") == nil then
  rawset(_G, "_oliverlukschander_vnc_mac_require", require)
end

local orig_require = rawget(_G, "_oliverlukschander_vnc_mac_require")
local VNC_DEVICES = { "hl-virtual-keyboard-wayvnc" }

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
      local alt = super_to_alt(keys)
      if alt then
        orig_bind(alt, description, dispatcher, with_vnc_device(options))
      end
    end
  end
  return result
end
