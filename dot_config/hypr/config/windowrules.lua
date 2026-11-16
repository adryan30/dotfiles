-- Window & layer rules — ported from niri/cfg/rules.kdl.
--
-- niri: window-rule { geometry-corner-radius 20; clip-to-geometry true }
--   -> covered globally by decoration.rounding (decorations.lua).
-- niri: window-rule { background-effect { blur true; xray false } }
--   -> covered globally by decoration.blur.enabled (decorations.lua).

-- Noctalia settings window.
hl.window_rule({
    match = { class = "^dev\\.noctalia\\.Noctalia$" },
    float = true,
    size  = { "1080", "920" },
})

-- Soundboard — quick floating clip picker (Mod+A).
hl.window_rule({
    match = { class = "^dev\\.potato\\.Soundboard$" },
    float = true,
    size  = { "420", "620" },
    move  = { "monitor_w - window_w - 32", "32" },
})

-- Steam main window floats; the actual "Steam" window itself stays tiled.
hl.window_rule({
    match = { class = "^steam$", title = "negative:^[Ss]team$" },
    float = true,
})

-- Steam notification toasts: floating, bottom-right, don't steal focus.
hl.window_rule({
    match = { class = "^steam$", title = "^notificationtoasts_\\d+_desktop$" },
    float = true,
    move  = { "monitor_w - window_w - 10", "monitor_h - window_h - 10" },
})
hl.window_rule({
    name  = "steam-toast-no-focus",
    match = { class = "^steam$", title = "^notificationtoasts_\\d+_desktop$" },
    no_focus = true,
})

-- Picture-in-Picture.
hl.window_rule({
    match = { class = "^(zen|firefox)$", title = "^Picture-in-Picture$" },
    float = true,
    size  = { "720", "405" },
    move  = { "monitor_w - window_w - 32", "monitor_h - window_h - 32" },
})

-- Zen/Firefox extension popups (Bitwarden, etc.) — see autostart.lua for why
-- this is a dynamic event hook rather than a static window_rule: Hyprland,
-- like niri, only evaluates float/size/move once at window-open time, and
-- these popups set their real title *after* opening. This reimplements
-- ~/.local/bin/niri-dynamic-float's two rules against Hyprland's own
-- documented pattern for this exact problem.
--
-- Caveats (both need live verification once actually logged into Hyprland —
-- not guessed further here to avoid shipping unverified API calls):
--   1. `hl.dsp.window.*` dispatchers default to "activewindow" (no window
--      selector passed, matching Hyprland's own docs example for this
--      pattern) — relies on the popup still holding focus when its title
--      lands, which should hold for how these popups normally open.
--   2. Position (niri put these top-right, 32px margin) is intentionally
--      NOT set here. The window_rule "move" effect documents an
--      expression grammar ("monitor_w - window_w - 32"), but that grammar
--      is only confirmed for *static rule effects*, not for the
--      `hl.dsp.window.move` runtime dispatcher used here — rather than
--      guess whether it also accepts expression strings, this only floats
--      + sizes the popup and leaves it wherever Hyprland's default
--      floating placement puts it. Revisit once you can test live.
--   3. `w.class` on the event payload is assumed to exist (window objects
--      expose `class` elsewhere in the API), not explicitly confirmed for
--      this specific event's payload shape in the docs fetched.
local function floatExtensionPopup(width, height)
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false }))
end

hl.on("window.title", function(w)
    if w == nil or w.class == nil then return end
    if not (w.class:match("^zen$") or w.class:match("^firefox$")) then return end

    if w.title and w.title:match("Extension:.*Bitwarden") then
        floatExtensionPopup(420, 560)
    elseif w.title and w.title:match("^Extension:") then
        floatExtensionPopup(380, 520)
    end
end)

-- Layer rules — Noctalia surfaces.
-- niri: layer-rule { match namespace="^noctalia-wallpaper"; place-within-backdrop true }
--   NOT PORTED — no Hyprland layer-rule effect for backdrop placement.
hl.layer_rule({
    match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd)$" },
    blur  = true,
    xray  = false,
})

-- niri: window-rule { match app-id="^gamescope$"; variable-refresh-rate true }
--   NOT PORTED — Hyprland has no per-window VRR toggle; monitors.lua sets
--   `vrr = 2` (fullscreen-only) on HDMI-A-1 instead, a monitor-level
--   approximation of niri's on-demand-for-gamescope rule.
