---
description: Disk hygiene snapshot for this Mac — free space, caches, stale worktrees, LaunchAgent state
---

Call the `hygiene_status` MCP tool from the mac-agent-hygiene server and present the result as a short
table: disk free and used %, DerivedData size, leftover plugin clones, Playwright profiles (locked / in
use), worktrees total vs stale, Xcode building yes/no, LaunchAgent loaded yes/no, `cleanupPeriodDays`.

Then say what you recommend: if stale worktrees > 0 or DerivedData > 2 GB, offer to run `hygiene_plan`
and show the plan before any `hygiene_apply`. If the LaunchAgent is not loaded, offer
`hygiene_schedule` with `action: "install"`. Never apply without showing the plan first.
