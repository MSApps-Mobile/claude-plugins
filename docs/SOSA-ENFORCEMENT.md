# SOSA™ Enforcement Guide

This repo checks SOSA compliance at three levels. Today only the first is automated, and none of the three blocks a merge: branch protection is **not** enabled on `main` (see [Recommended: Branch Protection](#recommended-branch-protection-not-yet-in-place)).

## 1. CI/CD — GitHub Actions (Automatic, reports only)

Every PR and push to `main` triggers `.github/workflows/sosa-lint.yml`:

- **SOSA four-pillar lint** — checks all plugins/skills against the checklist
- **Secret pattern scan** — fails the check on `api_key=` and `password=` assignments and on committed `.env` files (the lint script `scripts/sosa-lint.sh` additionally flags `apiKey` and `token=` assignments with long values). This is a pattern match, not a full secret scanner
- **SKILL.md presence** — ensures every plugin and skill has a role definition
- **Token efficiency** — warns on bloated skill descriptions (>3000 words)

A failing check shows as a red status on the PR, but it does **not** prevent a merge: no branch protection or required status check is configured on `main`, and `release.yml` pushes version-bump commits directly to `main`. See [SECURITY.md](../SECURITY.md) for the full list of what is and is not in place.

## 2. Local Linting (Pre-push)

Run before pushing:

```bash
./scripts/sosa-lint.sh .
```

This runs the same lint script that CI calls, with color-coded output. Running it is optional; nothing requires it.

## 3. PR Review Checklist (Human, convention only)

`.github/pull_request_template.md` includes the SOSA four-pillar checklist. Reviewers are asked to verify each item; this is a convention and is not enforced by any tool.

## Recommended: Branch Protection (not yet in place)

Branch protection is **not enabled** on `main` today (the GitHub API reports "Branch not protected"). To make the checks above blocking, a repository admin would enable it:

1. Go to **Settings → Branches → Branch protection rules**
2. Add rule for `main`:
   - ✅ Require pull request reviews before merging (1 reviewer)
   - ✅ Require status checks to pass — select `SOSA™ Four-Pillar Lint`
   - ✅ Require branches to be up to date
   - ✅ Do not allow bypassing the above settings

## Adding New Plugins/Skills

Every new plugin must include:
- `SKILL.md` with role spec, triggers, and boundaries
- `.mcp.json` or `.claude-plugin/plugin.json` with dependency manifest
- `CLAUDE.md` or `README.md` with documentation
- No hardcoded secrets — use `~/.config/` or env vars
