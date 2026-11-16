-- Output configuration — mirrors niri/cfg/display.kdl.
-- Run `hyprctl monitors all` to confirm output names match.

-- Ultrawide is primary, anchored top-left.
hl.monitor({ output = "DP-1", position = "0x0" })

-- Ultrawide sits bottom-left; TV sits top-right — its bottom-left corner
-- meets the ultrawide's top-right corner. Same layout as niri/cfg/display.kdl.
--
-- VRR: Hyprland has no per-window VRR toggle (niri's on-demand rule keys off
-- a gamescope window-rule match). `vrr = 2` (fullscreen-only) on this output
-- is the closest built-in equivalent — turns on for any fullscreen content,
-- not specifically gamescope. Approximate; revisit if it flickers on normal
-- fullscreen video/desktop use the way niri's rule was written to avoid.
hl.monitor({ output = "HDMI-A-1", position = "3440x-2160", vrr = 2 })
