-- Workspace rules — minimal, mirrors niri's DP-1-is-primary setup
-- (niri/cfg/display.kdl). Hyprland workspaces are global by default, unlike
-- niri's per-monitor ones — see docs/adr/0011 for that unavoidable gap.

hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
