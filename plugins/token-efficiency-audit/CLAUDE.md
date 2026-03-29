# CLAUDE.md — token-efficiency-audit

Developer notes for the Token Efficiency Audit plugin.

## Architecture

```
token-efficiency-audit/
├── .claude-plugin/config.json    — metadata with SOSA level, impact, pillar details
├── skills/token-efficiency-audit/
│   ├── SKILL.md                  — Main workflow (Plan→Act→Verify), ~150 lines
│   └── references/
│       └── optimization-patterns.md  — O6 pattern catalog, loaded only during audit
├── CONNECTORS.md
├── CLAUDE.md
└── README.md
```

## SOSA Compliance — Level 3

- **Supervised**: Presents findings and asks for approval before modifying any skill or scheduled task. High-impact changes (skill rewrites, task disabling) require explicit confirmation.
- **Orchestrated**: Follows Plan→Act→Verify execution loop. Parallel data gathering in Plan phase. Structured Notion output. Enforces O6 efficiency checks for the entire system. This plugin IS the O6 enforcement mechanism.
- **Secured**: Never touches credentials or .mcp.json. All changes logged in Notion audit report. Skill replacements delivered as .skill packages (user clicks to install).
- **Agent**: Role = token optimization (O6 enforcement). Tools = scheduled-tasks MCP + Notion + present_files. Memory = Notion audit reports. Planning = 10-pattern optimization catalog in references/.

## SOSA Dependency Chain

```
sosa-compliance-checker (runs full 4-pillar audit)
  └── token-efficiency-audit (runs O6 sub-audit for Orchestrated pillar)
```

The `sosa-compliance-checker` invokes this plugin when assessing the Orchestrated pillar's O6 checks. This plugin can also run standalone for focused efficiency optimization.

## Token Efficiency of This Plugin Itself

This plugin practices what it preaches:
- Description is ~100 words (covers all trigger phrases for broad triggering)
- SKILL.md body is ~150 lines (well under 400-line threshold)
- Heavy reference material (pattern catalog) is in references/ — only loaded during audit execution
- No inline data tables, no duplicated rules, no prose — pure imperative workflow
- SOSA metadata in config.json, not duplicated in SKILL.md

## Known Constraints

- Cannot write .skill files directly to Mac's `.claude/skills/` directory (read-only bindfs mount in Cowork VM). Uses `present_files` with .skill packaging instead.
- Cannot uninstall plugins or disconnect MCP servers programmatically — these are listed as manual items for the user.