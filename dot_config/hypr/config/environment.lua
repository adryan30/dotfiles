-- Environment variables — mirrors niri/cfg/misc.kdl's `environment {}` block.

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("LC_CTYPE", "pt_BR.UTF-8")
-- libqalculate (Noctalia calc) uses LC_MONETARY as the default conversion target
hl.env("LC_MONETARY", "pt_BR.UTF-8")

-- niri sets cursor theme/size via its `cursor {}` block; Hyprland only
-- exposes cursor *theme* through env vars (see config-options.md "Cursor" —
-- no theme field there, only behavioral ints).
hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "capitaine-cursors")
hl.env("HYPRCURSOR_SIZE", "24")
