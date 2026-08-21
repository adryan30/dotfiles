## Agent skills

### Issue tracker

Issues live in GitHub Issues for `adryan30/dotfiles` (via `gh`). See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: root `docs/adr/` (no `CONTEXT.md` yet). See `docs/agents/domain.md`.

## Chezmoi

Managed home files: edit only via the chezmoi source (`chezmoi source-path`). See `docs/adr/0001-chezmoi-source-is-canonical.md` and `docs/agents/chezmoi.md`.

Global skill (any workspace): `chezmoi` — read `~/.agents/skills/chezmoi/SKILL.md` before changing `$HOME` configs.
