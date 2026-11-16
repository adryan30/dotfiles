-- Keybindings — ported bind-by-bind from niri/cfg/keybinds.kdl, in the same
-- order and grouping, so the two files stay diffable against each other.
--
-- Hyprland's native "scrolling" layout (see decorations.lua) is what makes
-- niri's column vocabulary (consume/expel/swapcol/focus l·r) portable at
-- all — see https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- for the dispatcher reference this file leans on via hl.dsp.layout(msg).
--
-- Every bind below that isn't a literal 1:1 port is flagged inline as
-- APPROXIMATE (best available analogue, semantics may differ) or NOT PORTED
-- (no Hyprland equivalent found — omitted rather than guessed).

local mainMod = "SUPER"
local noctCall = "noctalia msg "

-- niri: Mod+Shift+ESCAPE { show-hotkey-overlay; }
-- NOT PORTED — Hyprland has no built-in hotkey-overlay. `hyprctl binds`
-- lists binds from a terminal if you need a reference.

---------------------------
---- APPLICATIONS ----
---------------------------

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd("zen-browser"))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd("discord"))
hl.bind(mainMod .. " + G",      hl.dsp.exec_cmd("steam"))
hl.bind(mainMod .. " + A",           hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher /sb"))
hl.bind(mainMod .. " + SHIFT + A",   hl.dsp.exec_cmd("/home/potato/.local/bin/soundboard"))

-- --- Noctalia ---
hl.bind(mainMod .. " + SHIFT + Return",   hl.dsp.exec_cmd(noctCall .. "panel-toggle wallpaper"))
hl.bind(mainMod .. " + S",                hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center"))
hl.bind(mainMod .. " + SHIFT + S",        hl.dsp.exec_cmd(noctCall .. "settings-toggle"))
hl.bind(mainMod .. " + CONTROL + Return", hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher"))
hl.bind("ALT + Space",                    hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher"))
hl.bind(mainMod .. " + SHIFT + C",        hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher /calc"))
hl.bind(mainMod .. " + ALT + L",          hl.dsp.exec_cmd(noctCall .. "session lock"))
hl.bind(mainMod .. " + SHIFT + Q",        hl.dsp.exec_cmd(noctCall .. "panel-toggle session"))
hl.bind(mainMod .. " + V",                hl.dsp.exec_cmd(noctCall .. "panel-toggle clipboard"))
hl.bind(mainMod .. " + N",                hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center notifications"))

hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("cursor --classic"))
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd("nautilus"))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctCall .. "volume-up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctCall .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(noctCall .. "volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(noctCall .. "mic-mute"),    { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd(noctCall .. "media next"),     { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd(noctCall .. "media previous"), { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd(noctCall .. "media pause"),    { locked = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noctCall .. "brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctCall .. "brightness-down"), { locked = true, repeating = true })

-----------------------------------------
---- WINDOW MOVEMENT AND FOCUS ----
-----------------------------------------

hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- Between columns
hl.bind(mainMod .. " + Left",  hl.dsp.layout("focus l"))
hl.bind(mainMod .. " + H",     hl.dsp.layout("focus l"))
hl.bind(mainMod .. " + Right", hl.dsp.layout("focus r"))
hl.bind(mainMod .. " + L",     hl.dsp.layout("focus r"))
-- Within a column's stack (generic direction focus, works under any layout)
hl.bind(mainMod .. " + Up",   hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + K",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + J",    hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + CONTROL + Left",  hl.dsp.layout("swapcol l"))
hl.bind(mainMod .. " + CONTROL + H",     hl.dsp.layout("swapcol l"))
hl.bind(mainMod .. " + CONTROL + Right", hl.dsp.layout("swapcol r"))
hl.bind(mainMod .. " + CONTROL + L",     hl.dsp.layout("swapcol r"))
hl.bind(mainMod .. " + CONTROL + Up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CONTROL + K",     hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CONTROL + Down",  hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + CONTROL + J",     hl.dsp.window.move({ direction = "d" }))

-- niri: focus-column-first/last, move-column-to-first/last
-- APPROXIMATE — the scrolling layout's "fit tobeg"/"fit toend" move the
-- *view*, not necessarily focus; there's no dedicated jump-to-first/last
-- column focus command. move-column-to-first/last has no analogue at all.
hl.bind(mainMod .. " + Home", hl.dsp.layout("fit tobeg"))
hl.bind(mainMod .. " + End",  hl.dsp.layout("fit toend"))
-- NOT PORTED: Mod+CTRL+Home/End (move-column-to-first/last)

-- niri: focus/move-monitor left/right/up/down
-- APPROXIMATE — with exactly 2 monitors, +1/-1 relative-monitor selectors
-- stand in for true directional left/right/up/down.
hl.bind(mainMod .. " + SHIFT + Left",  hl.dsp.focus({ monitor = "-1" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.focus({ monitor = "+1" }))
hl.bind(mainMod .. " + SHIFT + Up",    hl.dsp.focus({ monitor = "-1" }))
hl.bind(mainMod .. " + SHIFT + Down",  hl.dsp.focus({ monitor = "+1" }))

hl.bind(mainMod .. " + SHIFT + CONTROL + Left",  hl.dsp.window.move({ monitor = "-1" }))
hl.bind(mainMod .. " + SHIFT + CONTROL + Right", hl.dsp.window.move({ monitor = "+1" }))
hl.bind(mainMod .. " + SHIFT + CONTROL + Up",    hl.dsp.window.move({ monitor = "-1" }))
hl.bind(mainMod .. " + SHIFT + CONTROL + Down",  hl.dsp.window.move({ monitor = "+1" }))

-- NOT PORTED: Mod+Shift+V (switch-focus-between-floating-and-tiling) — no
-- Hyprland dispatcher for cycling focus specifically among floating windows.

hl.bind(mainMod .. " + BracketLeft",  hl.dsp.layout("consume_or_expel prev"))
hl.bind(mainMod .. " + BracketRight", hl.dsp.layout("consume_or_expel next"))

hl.bind(mainMod .. " + Comma",  hl.dsp.layout("consume"))
hl.bind(mainMod .. " + Period", hl.dsp.layout("expel"))

-- niri: switch-preset-column-width / -back
hl.bind(mainMod .. " + R",         hl.dsp.layout("colresize +conf"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.layout("colresize -conf"))

-- NOT PORTED: Mod+Ctrl+Shift+R (switch-preset-window-height), Mod+Ctrl+R
-- (reset-window-height) — the scrolling layout manages column *width*;
-- no per-window height-preset cycling dispatcher was found. Worth testing
-- manual resize (drag border) as the practical substitute.

---------------------------------
---- WORKSPACE SWITCHING ----
---------------------------------

-- niri: focus/move-workspace up/down (within-monitor, relative)
-- APPROXIMATE direction mapping — "down" -> next (m+1), "up" -> previous (m-1).
hl.bind(mainMod .. " + U", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + I", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + U", hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + I", hl.dsp.window.move({ workspace = "m-1" }))

hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.window.move({ workspace = "m-1" }))

-- NOT PORTED: WheelScrollLeft/Right (+Shift/+CTRL variants) — no confirmed
-- Hyprland horizontal-scroll bind key name; verify with `wev` before adding.
hl.bind(mainMod .. " + WheelScrollDown", hl.dsp.layout("focus r"))
hl.bind(mainMod .. " + WheelScrollUp",   hl.dsp.layout("focus l"))
hl.bind(mainMod .. " + CONTROL + WheelScrollDown", hl.dsp.layout("swapcol r"))
hl.bind(mainMod .. " + CONTROL + WheelScrollUp",   hl.dsp.layout("swapcol l"))

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,            hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + CONTROL + " .. i,  hl.dsp.window.move({ workspace = i }))
end

-- APPROXIMATE — "previous" workspace selector is long-standing Hyprland
-- vocabulary (hyprctl dispatch workspace previous); not re-verified against
-- the new Lua binding surface specifically. Confirm once running.
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

---------------------------
---- LAYOUT CONTROLS ----
---------------------------

hl.bind(mainMod .. " + CONTROL + F", hl.dsp.layout("fit expand"))
hl.bind(mainMod .. " + C",           hl.dsp.layout("center"))
-- APPROXIMATE — "fit visible" fits/centers all visible columns, closest
-- match for niri's center-visible-columns.
hl.bind(mainMod .. " + CONTROL + C", hl.dsp.layout("fit visible"))

-- niri percentages are of the *column*; Hyprland's colresize relative float
-- is read as a fraction — APPROXIMATE, not a guaranteed identical amount.
hl.bind(mainMod .. " + Minus", hl.dsp.layout("colresize -0.1"))
hl.bind(mainMod .. " + Equal", hl.dsp.layout("colresize +0.1"))

-- NOT PORTED: Mod+Shift+Minus/Equal (set-window-height ±10%) — no
-- percentage-based per-window height resize found for the scrolling layout.

---------------------
---- MODES ----
---------------------

hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
-- APPROXIMATE — niri's maximize-column (stretch this column full-width,
-- stay tiled) has no distinct Hyprland dispatcher separate from "fit
-- expand" (already bound to Mod+CTRL+F above); Mod+F instead maps to
-- Hyprland's own maximize concept (internal state, not column-width).
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- APPROXIMATE — Hyprland groups are a different mechanism (arbitrary
-- windows tabbed together) than niri's "make this whole column tabbed".
hl.bind(mainMod .. " + W", hl.dsp.group.toggle())
-- NOT PORTED: Mod+M (maximize-window-to-edges) — collapses into Mod+F above
-- given Hyprland's single maximize concept; binding both would be redundant.

---------------------------
---- SCREENSHOTS ----
---------------------------

-- Same grim/slurp/swappy pipeline as niri (compositor-agnostic tools).
hl.bind("Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]]))
-- niri's screenshot-screen/-window dispatchers are niri-native (no portal);
-- Hyprland has no equivalent built-in dispatcher, so these shell out to
-- hyprctl + grim directly instead. APPROXIMATE — copies to clipboard rather
-- than niri's copy-to-clipboard-only behavior for screen/window (same
-- end result, different tool).
hl.bind(mainMod .. " + Print",
    hl.dsp.exec_cmd([[grim -o "$(hyprctl -j activeworkspace | jq -r .monitor)" - | wl-copy]]))
hl.bind("ALT + Print",
    hl.dsp.exec_cmd([[grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" - | wl-copy]]))
-- APPROXIMATE — niri's Shift+Print opens its own interactive screenshot UI;
-- Hyprland has no built-in picker, so this reuses the region-select bind.
hl.bind("SHIFT + Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]]))

hl.bind("CONTROL + SHIFT + 1", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]]))
hl.bind("CONTROL + SHIFT + 2",
    hl.dsp.exec_cmd([[grim -o "$(hyprctl -j activeworkspace | jq -r .monitor)" - | wl-copy]]))
hl.bind("CONTROL + SHIFT + 3",
    hl.dsp.exec_cmd([[grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" - | wl-copy]]))
hl.bind("CONTROL + SHIFT + 4", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]]))

-------------------------------
---- EMERGENCY ESCAPE ----
-------------------------------

-- APPROXIMATE — niri's toggle-keyboard-shortcuts-inhibit specifically
-- disables an active shortcuts inhibitor. Hyprland's release_input_capture
-- releases an active input-capture session — same "unstick my keybinds"
-- intent, different underlying mechanism.
hl.bind(mainMod .. " + Escape", hl.dsp.release_input_capture())

-----------------------------
---- EXIT / POWER ----
-----------------------------

hl.bind("CONTROL + ALT + Delete", hl.dsp.exit())
-- Wiki cautions against binding dpms directly (recommends wrapping in a
-- timer); kept direct here to match niri's one-key-press simplicity — this
-- is a manual keypress, not automation, so the documented risk (undefined
-- behavior under programmatic/rapid triggering) shouldn't apply.
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.dpms({ action = "disable" }))

-- NOT PORTED: Mod+O (toggle-overview) — Hyprland has no built-in overview.
