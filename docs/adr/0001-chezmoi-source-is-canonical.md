# Chezmoi source is canonical for managed home files

Home configs that chezmoi tracks are owned by the source directory (`~/Developer/dotfiles`, `chezmoi source-path`), not by the live paths under `$HOME`. Targets are apply output. Edit the source (or `chezmoi edit` / `chezmoi add`), then `chezmoi apply` — never treat a managed target as the durable copy. Linux vs macOS filtering uses templated `.chezmoiignore` against **target** paths (names under `$HOME`), not source names (`dot_*`). Workstation *behavior* decisions stay in playground ADRs; this ADR is only ownership and the edit path.

## Consequences

- In-place edits under `$HOME` for a managed file drift until the next apply overwrites them (or linger as a false sense of permanence if never re-added).
- New managed files enter via `chezmoi add` (or create under source + apply), not as orphans only under `$HOME`.
- Secrets stay out of the cleartext tree (`private_`, age, omit from add).
