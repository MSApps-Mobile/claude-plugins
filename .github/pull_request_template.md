## Summary

<!-- Brief description of changes -->

## SOSA™ Compliance Checklist

### Supervised
- [ ] SKILL.md defines clear role spec (what it does, when it triggers)
- [ ] Impact level declared (low/medium/high)
- [ ] High-impact actions include human approval gates

### Orchestrated
- [ ] Dependencies declared (.mcp.json or plugin.json)
- [ ] SKILL.md is lean (<2000 words, no duplicated data)
- [ ] Uses Plan → Act → Verify execution loop where applicable
- [ ] No duplicate or unused MCP connectors

### Secured
- [ ] No hardcoded secrets, API keys, or passwords
- [ ] No .env files committed
- [ ] Credentials reference local config or environment variables
- [ ] External data inputs validated for prompt injection

### Agents (RTMP)
- [ ] **R**ole — Clear boundaries and success criteria in SKILL.md
- [ ] **T**ools — Tool manifest defined (which APIs/MCPs it accesses)
- [ ] **M**emory — Persistence strategy documented (if applicable)
- [ ] **P**lanning — Step-by-step workflow with preconditions

## Test Plan

- [ ] Ran `scripts/sosa-lint.sh` locally — passes
- [ ] Tested manually in Cowork session
