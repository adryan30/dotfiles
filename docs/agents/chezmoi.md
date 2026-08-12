# Chezmoi workflow for agents

Operational companion to [ADR-0001](../adr/0001-chezmoi-source-is-canonical.md). Prefer the global `chezmoi` skill when available; this doc is the repo-local copy of the same rules.

## Before any `$HOME` edit

1. Resolve source: `chezmoi source-path`
2. Check the path: `chezmoi source-path -- <absolute-or-home-path>`  
   - Prints a source path → **managed**. Edit that source file only.  
   - Errors / empty → unmanaged. Edit the target only if it should stay unmanaged; otherwise `chezmoi add` after the change (or add then edit source).
3. Optional inventory: `chezmoi managed`

## Edit → apply

- Change files under the sourceDir (or `chezmoi edit -- <target>`).
- Preview: `chezmoi apply --dry-run --verbose`
- Apply: `chezmoi apply`
- Git: commit in the source repo when asked; `autoCommit` / `autoPush` are off.

## Ignore and OS split

`.chezmoiignore` patterns are **destination** paths (`.config/niri`, not `dot_config/niri`). Templates gate macOS-only vs Linux-only entries. Do not “fix” ignore entries to source names.

## Secrets

Do not `chezmoi add` credentials, tokens, or machine-local secrets into cleartext source. Use `private_` / age-encrypted sources, or leave them unmanaged and ignored.
