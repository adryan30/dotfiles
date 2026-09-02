function stl-add --description 'Add a non-Steam game shortcut via SteamTinkerLaunch'
    set -l exe $argv[1]
    if test -z "$exe"
        echo "Usage: stl-add <path-to-exe> [app-name] [compat-tool]" >&2
        echo "  compat-tool e.g. proton_experimental, GE-Proton (steamtinkerlaunch ct list)" >&2
        return 1
    end
    if not test -e "$exe"
        echo "stl-add: no such file: $exe" >&2
        return 1
    end
    set -l exe (realpath "$exe")
    set -l name $argv[2]
    if test -z "$name"
        set name (path basename "$exe" | string replace -r '\.[^.]*$' '')
    end
    set -l ct $argv[3]
    set -l startdir (path dirname "$exe")

    if pgrep -x steam >/dev/null
        echo "warning: Steam is running — close it first or the shortcut won't stick" >&2
    end

    echo "Adding '$name' ($exe)"
    if test -n "$ct"
        steamtinkerlaunch ansg -ep="$exe" -an="$name" -sd="$startdir" -ct="$ct"
    else
        steamtinkerlaunch ansg -ep="$exe" -an="$name" -sd="$startdir"
    end
end
