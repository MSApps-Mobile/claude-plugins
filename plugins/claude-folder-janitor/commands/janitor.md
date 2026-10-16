---
description: Clean provably-safe clutter out of ~/.claude — dry run by default, "/janitor apply" to delete
argument-hint: "[apply]"
---

Run the janitor script. If `$ARGUMENTS` is exactly `apply`, run it in apply mode; otherwise run the dry run.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/janitor.sh" $ARGUMENTS
```

Each output line is `rule<TAB>KB<TAB>path<TAB>reason`, followed by one `summary` line.

- **Dry run:** group the candidates by rule (backup, session-env, changelog, orphan) and show for each rule
  the count, the total size and up to five example paths with their reasons. End with the reclaimable total
  and say that `/janitor apply` deletes exactly this list.
- **Apply:** report removed, failed, the space freed and the elapsed time from the summary line. If
  anything failed, show those lines from stderr.

Never run `apply` unless the user typed it. Do not delete anything by hand that the script did not list.
