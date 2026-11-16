source /usr/share/cachyos-fish-config/cachyos-config.fish

fish_add_path --prepend $HOME/.local/bin/

# English UI, Brazilian ctype (Compose trimmed in ~/.XCompose) — mirrors /etc/locale.conf
set -gx LC_CTYPE pt_BR.UTF-8
# BRL as local currency (qalc / Noctalia calc auto-convert)
set -gx LC_MONETARY pt_BR.UTF-8

# Docker rootless (docker-rootless package)
set -gx DOCKER_HOST unix://$XDG_RUNTIME_DIR/docker.sock

# HashiCorp Vault — public mesh address (see infra's docs/agents/vault.md)
set -gx VAULT_ADDR https://vault.adryan.me

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
