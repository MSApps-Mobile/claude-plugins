# How to submit MSApps plugins to the Anthropic marketplace

Steps to land a plugin in [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official). Mirrors the workflow used by PR #1813 (mercadopago) and the dozens of plugins already merged.

## 1. Confirm the plugin is ready

Read `AUDIT.md` in this folder. Don't open a PR for a plugin marked "NOT READY" — reviewers will close it.

## 2. Pin the SHA

After your last fix is on `main`:

```bash
gh api repos/MSApps-Mobile/claude-plugins/branches/main --jq .commit.sha
```

Paste that SHA into the entry's `source.sha` field in `MARKETPLACE_ENTRIES.json` (replace `REPLACE_WITH_PINNED_SHA`).

## 3. Fork and branch

```bash
gh repo fork anthropics/claude-plugins-official --clone
cd claude-plugins-official
git checkout -b add-cowork-mem-plugin
```

## 4. Edit `.claude-plugin/marketplace.json`

Open it, find the alphabetical insertion point for your plugin's `name` (the file is sorted), and paste the entry from `MARKETPLACE_ENTRIES.json` (just the inner object — the keys in `MARKETPLACE_ENTRIES.json` like `"cowork-mem"` are organizational, not part of the spec).

Validate JSON before committing:

```bash
jq . .claude-plugin/marketplace.json > /dev/null && echo OK
```

## 5. Open the PR

```bash
git add .claude-plugin/marketplace.json
git commit -m "Add cowork-mem plugin"
git push -u origin add-cowork-mem-plugin
gh pr create --repo anthropics/claude-plugins-official \
  --title "Add cowork-mem plugin" \
  --body "Cowork-mem gives Claude persistent memory across Cowork sessions. Sourced from MSApps-Mobile/claude-plugins at plugins/cowork-mem, pinned to <SHA>."
```

One PR per plugin. Repeat for each.

## 6. After review

If a reviewer requests changes, make them in `MSApps-Mobile/claude-plugins`, push to `main`, get the new SHA, and update the PR's marketplace.json entry to point at the new SHA. Then comment on the PR.

## 7. Update process

Anthropic pins each entry to a specific commit. To ship updates to a plugin already in the marketplace, open a new PR that just bumps the `sha` field.
