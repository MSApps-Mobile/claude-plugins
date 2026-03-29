# SOSA™ Enforcement Guide

This repo enforces SOSA compliance at three levels:

## 1. CI/CD — GitHub Actions (Automatic)

Every PR and push to `main` triggers `.github/workflows/sosa-lint.yml`:

- **SOSA four-pillar lint** — checks all plugins/skills against the checklist
- **Secret scanning** — blocks hardcoded API keys, passwords, tokens
- **SKILL.md presence** — ensures every plugin and skill has a role definition
- **Token efficiency** — warns on bloated skill descriptions (>3000 words)

PRs that fail the SOSA lint **cannot be merged**.

## 2. Local Linting (Pre-push)

Run before pushing:

```bash
./scripts/sosa-lint.sh .
```

This runs the same checks as CI, with color-coded output.

## 3. PR Review Checklist (Human)

Every PR uses `.github/pull_request_template.md` which includes the full SOSA four-pillar checklist. Reviewers must verify each item.

## Recommended: Branch Protection

To fully enforce SOSA, enable branch protection on `main`:

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
