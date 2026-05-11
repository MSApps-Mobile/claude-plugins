# Anthropic Marketplace Submission — Audit Report

**Date:** 2026-05-11
**Target:** [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)
**Source repo:** `MSApps-Mobile/claude-plugins` @ pinned SHA (TBD on push)
**Submission template:** PR #1813 (mercadopago) — adds an entry to `.claude-plugin/marketplace.json` using `source.source: "git-subdir"`.

---

## Verdict per plugin

| Plugin | Status | Blockers | Recommendation |
|---|---|---|---|
| `cowork-mem` | READY | None | Submit now |
| `notion-memory` | READY | None | Submit now |
| `opsagent-shopify` | NOT READY | 2 blockers | Fix before submitting |
| `whatsapp-mcp` | NOT READY | 1 blocker | Fix before submitting |

---

## cowork-mem — READY

- `.claude-plugin/plugin.json` present and well-formed (name, version 0.2.1, description, author, license, repository, privacy, terms, keywords).
- 7 skills (`cowork-mem`, `do`, `knowledge-agent`, `make-plan`, `mem-search`, `smart-explore`, `timeline-report`) — all real folders.
- `hooks/hooks.json` present.
- README is clear, value-proposition-first, attributes inspiration to `claude-mem` by `@thedotmack`.
- No leaked secrets, no hardcoded absolute paths, no `.env` files.

No changes required.

---

## notion-memory — READY

- `.claude-plugin/plugin.json` present and well-formed (v2.0.1).
- 5 skills bundled: 1 MSApps (`notion-memory`) + 4 Anthropic-authored (`notion-knowledge-capture`, `notion-meeting-intelligence`, `notion-research-documentation`, `notion-spec-to-implementation`).
- Anthropic attribution handled correctly in both `plugin.json` (`bundled_skills` array names each author) and README (table with "Anthropic" in author column, links to Anthropic's original distribution).
- License is MIT (MSApps' own contributions); Anthropic skills are noted as © Anthropic, re-published unmodified.
- No leaked secrets, no hardcoded paths.

No changes required.

*Note for reviewer pre-emption:* Anthropic published these Notion skills openly via Claude's official LinkedIn announcement and a public Notion site. Re-bundling them with attribution is consistent with how marketplace ecosystems typically handle official-sample re-distribution. If a reviewer pushes back, the fallback is to ship a single-skill plugin (`notion-memory` only) and link out to the four Anthropic skills.

---

## opsagent-shopify — NOT READY (2 blockers)

**Blocker 1 — `mcp-server/dist/` is not committed.**
`plugin.json` declares the MCP server entrypoint as `mcp-server/dist/server.js`, but only `mcp-server/src/` is in the repo. A fresh install will fail.

Fix options:
- (a) Commit a built `dist/` (simple, but adds compiled JS to the repo).
- (b) Add a `postinstall` build step to `mcp-server/package.json` (`"postinstall": "tsc"`) and document that `npm install` must run inside the plugin folder.
- (c) Switch to a runtime that doesn't need a build (e.g., `tsx` or `ts-node` invocation in the `command` line).

**Blocker 2 — README admits skill source is partial.**
> "Source for this skill currently ships in the rpm plugin distribution; will be folded in here in a future PR."

Only 1 of the 3 skills mentioned in the README (`shopify-mcp`, `symmetry-install`, `shopify-partner-marketing`) has a real `SKILL.md` in the plugin. Reviewers will flag this as the marketplace listing implies functionality the repo doesn't deliver.

Fix: fold the three skill folders in before submitting, OR rewrite the README to only describe what actually ships in this version.

---

## whatsapp-mcp — NOT READY (1 blocker)

**Blocker — hardcoded user-specific path in `agents/contact-finder.md`:**

```
sqlite3 "/Users/michalshatz/Library/Application Support/AddressBook/Sources/"*"/AddressBook-v22.abcddb"
```

This path only works on Michal's Mac. Other users have their own home directory. Fix:

```
sqlite3 "$HOME/Library/Application Support/AddressBook/Sources/"*"/AddressBook-v22.abcddb"
```

Other notes (non-blocking):
- `.mcp.json` uses `${WHATSAPP_MCP_PATH}` for both `args` and `env` value — works but slightly redundant. Optional cleanup.
- Requires user to install Go bridge + Python MCP server out-of-band. README documents this clearly. Acceptable for marketplace but adds onboarding friction.

---

## Submission flow

1. Fix blockers (`opsagent-shopify`, `whatsapp-mcp`) and push to `main`.
2. Re-read the SHA on `main` after the push (`gh api repos/MSApps-Mobile/claude-plugins/branches/main --jq .commit.sha`).
3. Fork `anthropics/claude-plugins-official`, edit `.claude-plugin/marketplace.json`, append the entries from `MARKETPLACE_ENTRIES.json` (in this folder) with the new SHA.
4. Open one PR per plugin (matching the upstream convention — PR #1813 was a single plugin).
5. Use PR title format: `Add {plugin-name} plugin`.

---
