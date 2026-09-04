-- Look and feel — mirrors niri/cfg/layout.kdl + niri/cfg/misc.kdl's blur block.

hl.config({
    general = {
        -- Hyprland's native "scrolling" layout (0.56+) is the real analogue
        -- of niri's column model — see docs/adr/0011 for the mapping this
        -- unlocks in config/binds.lua.
        layout = "scrolling",
        gaps_in = 16, -- niri's single `gaps 16` applies to both in/out
        gaps_out = 16,
        -- niri doesn't customize border colors (no `col` block in its
        -- layout.kdl), so left at Hyprland defaults here too, for parity.
    },
    decoration = {
        rounding = 20, -- niri: geometry-corner-radius 20
        blur = {
            enabled = true,
            passes = 2,   -- niri: blur { passes 2 }
            size = 3,     -- closest analogue of niri's `offset 3.0` (sample
                          -- distance per pass) — different blur engines,
                          -- approximate, not a 1:1 unit match.
            noise = 0.03, -- niri: blur { noise 0.03 }
            vibrancy = 1.0, -- closest analogue of niri's `saturation 1.0`
        },
    },
    scrolling = {
        -- niri: preset-column-widths { proportion 0.33333/0.5/0.66667 }
        column_width = 0.33333,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
    },
})

-- niri: window-rule { geometry-corner-radius 20; clip-to-geometry true }
--   -> covered globally by decoration.rounding above.
-- niri: window-rule { background-effect { blur true; xray false } }
--   -> covered globally by decoration.blur.enabled above.
