---
name: chezmoi
description: >-
  Edit chezmoi-managed dotfiles and home configs safely. Use when changing
  files under $HOME, ~/.config, ~/.local, ~/.zshrc, XCompose, niri, noctalia,
  pipewire, wireplumber, EasyEffects, or anything in ~/Developer/dotfiles;
  when running chezmoi add/edit/apply; or when an agent might write a target
  path instead of the source.
---

# Chezmoi

Managed home files are owned by the **source**, not the live target. SourceDir is `chezmoi source-path` (normally `~/Developer/dotfiles`). Decision record: `~/Developer/dotfiles/docs/adr/0001-chezmoi-source-is-canonical.md`.

## Steps

1. **Classify the path** before create/edit/delete under `$HOME` or the source repo:
   - `src="$(chezmoi source-path -- "$TARGET" 2>/dev/null || true)"`
   - Non-empty `src` → managed; edit `"$src"` only.
   - Empty → unmanaged; leave unmanaged, or `chezmoi add "$TARGET"` then edit the new source path.
2. **Edit source** (or `chezmoi edit -- "$TARGET"`). Do not write managed targets in place.
3. **Apply**: `chezmoi apply --dry-run --verbose`, then `chezmoi apply` when the diff is right.
4. **Ship**: in SourceDir (`git -C "$(chezmoi source-path)"`), commit every source change from this work and `git push` to origin. This is part of the edit, not a later favour.
5. **Ignore / OS split**: patterns in `.chezmoiignore` match **target** paths (`.config/niri`), never source names (`dot_config/...`).
6. **Secrets**: skip cleartext add for credentials; use `private_` / age or keep unmanaged.

## Done when

Every touched managed file was changed in sourceDir (or via `chezmoi edit`/`add`), apply was considered, no managed target was treated as the durable copy, and those source commits are on `origin`.
