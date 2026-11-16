-- Animations — best-effort translation of niri/cfg/animation.kdl.
-- Hyprland's animation system (bezier/spring curves assigned to leaves) is
-- structurally different from niri's per-action spring/duration config, so
-- these are approximations of the *feel*, not numerically equivalent.
-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for how
-- the scrolling layout's own transitions (column focus/move) ride on the
-- "windows"/"workspaces" leaves below — there's no separate leaf for niri's
-- "horizontal-view-movement".

-- Snappy, near-critically-damped spring — analogue of niri's springs, which
-- all use damping-ratio 1.0 (critically damped) with stiffness 800-1000.
hl.curve("niriSnap", { type = "spring", mass = 1, stiffness = 900, dampening = 30 })

-- niri: window-open { duration-ms 200; curve "ease-out-quad" }
hl.curve("niriEaseOutQuad", { type = "bezier", points = { {0.25, 0.46}, {0.45, 0.94} } })
-- niri: window-close { duration-ms 200; curve "ease-out-cubic" }
hl.curve("niriEaseOutCubic", { type = "bezier", points = { {0.33, 1}, {0.68, 1} } })

hl.animation({ leaf = "global",      enabled = true, speed = 2, bezier = "niriEaseOutQuad" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 2, bezier = "niriEaseOutQuad" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2, bezier = "niriEaseOutCubic" })
-- niri: window-movement (spring stiffness 800) — no separate Hyprland leaf
-- for window resize; windowsMove covers both drag-move and layout-driven
-- reflow (the closest analogue of niri's window-resize spring too).
hl.animation({ leaf = "windowsMove", enabled = true, spring = "niriSnap" })
-- niri: workspace-switch (spring stiffness 1000)
hl.animation({ leaf = "workspaces",  enabled = true, spring = "niriSnap", style = "slide" })

-- NOT PORTED — no Hyprland equivalent:
--   config-notification-open-close  (niri's config-reload toast; Hyprland has none)
--   screenshot-ui-open              (niri's built-in interactive screenshot picker;
--                                    we use grim+slurp+swappy instead, see binds.lua)
--   overview-open-close             (niri's overview; Hyprland has no overview concept)
