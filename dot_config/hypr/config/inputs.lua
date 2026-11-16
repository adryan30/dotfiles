-- Input configuration — mirrors niri/cfg/input.kdl.

hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "intl",
        -- Keychron K8 Pro (US ANSI) + dead keys; BR accents via LC_CTYPE=pt_BR
        -- ~/.XCompose: '+c -> ç; other non-BR dead-key combos stay literal
        numlock_by_default = true,
        -- follow_mouse = 1 (Hyprland default) already matches niri's
        -- focus-follows-mouse; not set explicitly.
        touchpad = {
            tap_to_click = true,
            natural_scroll = true,
        },
    },
})

-- niri's `gestures { hot-corners { off } }` disables opening the overview via
-- a screen-corner hover. Hyprland has no hot-corner/overview concept, so
-- there's nothing to disable — intentionally omitted.
