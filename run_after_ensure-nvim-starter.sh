#!/bin/sh
# LazyVim starter lives on disk; chezmoi only overlays custom files.
# After apply (or first boot), restore base starter files if missing —
# without clobbering managed overlays or an existing lazy-lock.json.
set -eu

NVIM_CONFIG="${HOME}/.config/nvim"

if [ -f "${NVIM_CONFIG}/init.lua" ] && [ -f "${NVIM_CONFIG}/lua/config/lazy.lua" ]; then
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ensure-nvim-starter: git not found; skip LazyVim bootstrap" >&2
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth=1 https://github.com/LazyVim/starter.git "$TMP/starter"

mkdir -p "${NVIM_CONFIG}/lua/config" "${NVIM_CONFIG}/lua/plugins"

# Base files from starter — never overwrite existing (chezmoi overlays win).
for f in init.lua stylua.toml LICENSE .gitignore .neoconf.json; do
  if [ -f "$TMP/starter/$f" ] && [ ! -f "${NVIM_CONFIG}/$f" ]; then
    cp "$TMP/starter/$f" "${NVIM_CONFIG}/$f"
  fi
done

for f in lazy.lua options.lua autocmds.lua; do
  if [ -f "$TMP/starter/lua/config/$f" ] && [ ! -f "${NVIM_CONFIG}/lua/config/$f" ]; then
    cp "$TMP/starter/lua/config/$f" "${NVIM_CONFIG}/lua/config/$f"
  fi
done

# First-time lock only; later updates stay local (not in chezmoi).
if [ ! -f "${NVIM_CONFIG}/lazy-lock.json" ] && [ -f "$TMP/starter/lazy-lock.json" ]; then
  cp "$TMP/starter/lazy-lock.json" "${NVIM_CONFIG}/lazy-lock.json"
fi

# Starter sample plugin is noise.
rm -f "${NVIM_CONFIG}/lua/plugins/example.lua"

echo "ensure-nvim-starter: LazyVim starter base ready at ${NVIM_CONFIG}"
