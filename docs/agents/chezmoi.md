# Chezmoi workflow for agents

Operational companion to [ADR-0001](../adr/0001-chezmoi-source-is-canonical.md). Prefer the global `chezmoi` skill when available; this doc is the repo-local copy of the same rules.

## Before any `$HOME` edit

1. Resolve source: `chezmoi source-path`
2. Check the path: `chezmoi source-path -- <absolute-or-home-path>`  
   - Prints a source path → **managed**. Edit that source file only.  
   - Errors / empty → unmanaged. If it should become managed (any new config, plugin, or script meant to persist), create it under the sourceDir and `chezmoi apply`; never write the target first and add it later. Editor tools on live targets leave Cursor inline diffs that rewrite the file on every startup.
3. Optional inventory: `chezmoi managed`

## Edit → apply

- Change files under the sourceDir (or `chezmoi edit -- <target>`).
- Preview: `chezmoi apply --dry-run --verbose`
- Apply: `chezmoi apply`
- Git: commit the sourceDir repo and push to origin after apply. The chezmoi skill owns this; source changes ship in the same turn as the edit.

## Ignore and OS split

`.chezmoiignore` patterns are **destination** paths (`.config/niri`, not `dot_config/niri`). Templates gate macOS-only vs Linux-only entries. Do not “fix” ignore entries to source names.

## Secrets

Do not `chezmoi add` credentials, tokens, or machine-local secrets into cleartext source. Use `private_` / age-encrypted sources, or leave them unmanaged and ignored.
