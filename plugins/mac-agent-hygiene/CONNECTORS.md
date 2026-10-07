# Connectors

## Required

- None. Everything runs on the local Mac: bash, launchd, git. The MCP server is bundled
  (`node ${CLAUDE_PLUGIN_ROOT}/server/index.js`) and needs no credentials.

## Optional

- **GitHub CLI (`gh`)** — if installed and authenticated, the worktree check can recognise a branch
  that was squash-merged (`gh pr list --state merged`). Without it, only worktrees whose HEAD is on a
  remote-tracking ref are eligible; everything else is kept. Read-only use.
