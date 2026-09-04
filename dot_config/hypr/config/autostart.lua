-- Auto-start — mirrors niri/cfg/autostart.kdl's `spawn-at-startup "noctalia"`.
--
-- NOT PORTED AS-IS: ~/.local/bin/niri-dynamic-float. It floats Zen/Firefox
-- extension popups (Bitwarden etc.) whose real title lands *after* the
-- window opens, by watching niri's event stream over $NIRI_SOCKET — so it
-- can't run under Hyprland. Its *purpose* is still needed: per Hyprland's
-- own docs, static window rules (float/size/move) are evaluated once at
-- open time and never re-checked against a later title change, same
-- limitation as niri. Hyprland's documented fix is a native event hook
-- instead of an external daemon — see the `hl.on("window.title", ...)`
-- handler in windowrules.lua, which reimplements the same two rules
-- (Bitwarden-specific + general extension popup) using dispatchers.

hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
end)
