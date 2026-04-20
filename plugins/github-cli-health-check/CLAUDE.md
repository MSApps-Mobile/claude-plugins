# github-cli-health-check — Task Notes

## Purpose

Daily health check for the GitHub CLI (`gh`). Verifies installation,
authentication, repo access, and API rate limit. Ships as two redundant
paths so a single-runtime failure still produces a report.

## Two live paths

1. **Routine (cloud)** — runs on Anthropic-managed Claude Code cloud
   infrastructure. Native `gh` via environment setup script; auth via the
   Claude GitHub App's `GITHUB_TOKEN` re-exported as `GH_TOKEN`. Registered
   at `claude.ai/code/routines` or via `/schedule`. Prompt body lives at
   `routines/prompt.md`. See `routines/README.md` for the registration
   walkthrough.
2. **Cowork + Desktop Commander** — runs in a Cowork scheduled task on the
   user's Mac. Routes every `gh` call through
   `mcp__Desktop_Commander__start_process` to the Mac's `/opt/homebrew/bin/gh`,
   authenticated via the Mac keyring. The Cowork VM sandbox cannot reach
   `api.github.com` directly — see
   [claude-code#37970](https://github.com/anthropics/claude-code/issues/37970).

The VM Bash path is intentionally NOT a third live path today. It's
structurally blocked by the Cowork proxy allowlist. When #37970 closes, add
it back as an interactive sanity check, but keep the Routine primary.

## Commands (both paths)

```bash
gh --version
gh auth status
gh repo list --limit 5 --json name,visibility,description,updatedAt,primaryLanguage
gh api rate_limit
```

## Output

Report file: `github-health-check-YYYY-MM-DD.md`, header tag
`(Routine / cloud)` or `(Cowork / DC)` to identify the runtime.

- **Routine path**: the final reply in the cloud session is the report.
  Sessions live at `claude.ai/code/session_XXX` and are bookmarkable.
  Optional: route the same summary to a connected MCP (Slack, Notion) if
  you want a persistent copy outside of claude.ai.
- **Cowork + DC path**: saved to
  `$HOME/Claude/Scheduled/github-cli-health-check/` (or
  `$HOME/Documents/Claude/Scheduled/github-cli-health-check/` depending on
  where the Mac's Claude workspace lives). Never inside a git repo and
  never in the Cowork outputs folder — those either leak to remotes or
  vanish between sessions.

## Version History

| Version | Date       | Change |
|---------|------------|--------|
| 0.1.0   | 2026-03-27 | Initial — Bash tool (broken: gh not in sandbox) |
| 0.2.0   | 2026-03-29 | Fixed — all gh via Desktop Commander |
| 0.3.0   | 2026-03-31 | Switched to Bash with auto-download of gh + GH_TOKEN |
| 0.4.0   | 2026-04-02 | Clarified sandbox limitations: no network/sudo in Bash |
| 0.5.0   | 2026-04-03 | Try Bash first, apt install, fall back to Desktop Commander |
| 0.6.0   | 2026-04-06 | Removed org-specific references |
| 0.7.0   | 2026-04-20 | Reports save to `~/Claude/Scheduled/...`; scrubbed private info |
| 0.8.0   | 2026-04-20 | VM Bash as required primary, DC as emergency fallback |
| 0.9.0   | 2026-04-20 | Documented the upstream VM block (#37970); DC is the real Cowork path |
| 0.10.0  | 2026-04-20 | **Dual-path**: cloud Routine + Cowork+DC, redundant by design. New `routines/` directory with prompt, setup script, and registration guide. SKILL.md rewritten to v3.0.0 to reflect the three runtime contexts (Routine / Cowork+DC / local interactive). |
