function parseStatus(text) {
  try {
    var obj = JSON.parse(String(text || "").trim())
    return {
      hookPresent: !!obj.hookPresent,
      bindsActive: !!obj.bindsActive,
      wayvncMac: !!obj.wayvncMac
    }
  } catch (e) {
    return { hookPresent: false, bindsActive: false, wayvncMac: false }
  }
}

function ready(status) {
  return !!(status && status.hookPresent && status.bindsActive)
}

function statusLabel(status) {
  if (ready(status) && status.wayvncMac) return "On"
  if (ready(status)) return "Binds on"
  if (status && status.hookPresent && !status.bindsActive) return "Reload needed"
  return "Off"
}

function statusMeta(status) {
  if (ready(status) && status.wayvncMac) return "Cmd from a Mac VNC client is Super"
  if (ready(status)) return "Super shortcuts are cloned onto Alt; WayVNC keymap not applied"
  if (status && status.hookPresent && !status.bindsActive) return "Hook is installed; reload Hyprland if Cmd does nothing"
  return "Install the mapping so Cmd over VNC matches Super"
}
