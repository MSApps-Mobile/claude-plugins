# Connectors

## Required

- None. The janitor is one bash script that reads and deletes files under `~/.claude`. It makes no
  network calls and needs no credentials.

## Optional

- **Claude Code CLI (`claude`)** — used only to read the installed version for the changelog rule.
  Without it, that rule is skipped.
