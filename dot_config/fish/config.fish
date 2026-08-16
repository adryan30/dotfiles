source /usr/share/cachyos-fish-config/cachyos-config.fish

fish_add_path --prepend $HOME/.local/bin/

# English UI, Brazilian ctype (Compose trimmed in ~/.XCompose) — mirrors /etc/locale.conf
set -gx LC_CTYPE pt_BR.UTF-8

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

if status is-interactive
    atuin init fish | source
    if command -q mise
        mise activate fish | source
    end
end
