# SOSA Compliance Checklist

Detailed check items for each pillar.

## Pillar 1: Supervised

### S1 — Impact Classification
- Skill declares impact level (low/medium/high)
- Low: Read-only, local-only, formatting, diagnostics
- Medium: Writes to external services, sends messages, modifies user data
- High: Financial transactions, bulk outreach, public posting, credential management

### S2 — Human-in-the-Loop Gates
- Low-impact: May operate fully autonomously
- Medium-impact: Log actions OR confirm first-time actions
- High-impact: Require explicit human approval
- RED FLAG: "do not ask", "no confirmation", "אין לשאול", "ללא אישור"

### S3 — Trust Gradient
- Differentiates first-time vs repeat actions
- Failure patterns escalate to tighter supervision

### S4 — Audit Trail
- Actions logged (summary email, Notion, structured report)
- Log includes: action type, timestamp, target, outcome

### Scoring
- PASS: S1 + S2 + S4 all met
- PARTIAL: Some actions gated, others not
- FAIL: S2 missing for high-impact skill

## Pillar 2: Orchestrated

### O1 — Execution Model
- Follows Plan → Act → Verify pattern
- Error handling at each step

### O2 — Structured Outputs
- JSON, typed reports, defined schemas
- Not just free-text

### O3 — Dependency Declaration
- Required MCP servers, connectors listed
- Missing deps produce clear errors

### O4 — Context Sharing
- Uses structured registry (Notion, JSON, Calendar)
- Decoupled — failure of one skill doesn't corrupt shared context

### Scoring
- PASS: O1 + O2 + O3 all met
- PARTIAL: Structured workflow but no verification
- FAIL: Fire-and-forget, no error handling

## Pillar 3: Secured

### C1 — Credential Management
- No hardcoded API keys, tokens, passwords
- Credentials in config files or env vars
- Regex patterns to scan:
  - UUID keys: [a-f0-9]{8}-[a-f0-9]{4}-...-[a-f0-9]{12}
  - OpenAI keys: sk-[a-zA-Z0-9]{20,}
  - GitHub PAT: ghp_[a-zA-Z0-9]{36}
  - AWS keys: AKIA[0-9A-Z]{16}
  - Google API: AIza[0-9A-Za-z-_]{35}

### C2 — Prompt Injection Defense
- If skill processes external data: has injection scanning
- Covers: direct injection, action hijacking, exfiltration, encoding, context manipulation

### C3 — Supply Chain
- uvx/npx packages pinned to exact versions
- No wildcard or "latest"

### C4 — Capability Scoping
- Only accesses necessary tools/APIs
- Tool manifest declared

### Scoring
- PASS: C1 + C2 (if applicable) + C3 + C4 all met
- PARTIAL: No hardcoded secrets but missing scanning or pinning
- FAIL: Hardcoded credentials OR external data without injection defense

## Pillar 4: Agents

### A1 — Role Specification (R)
- Clear domain boundaries in SKILL.md
- Exclusions defined (what NOT to do)
- Success criteria defined

### A2 — Tool Manifest (T)
- Required tools listed
- .mcp.json present for integrations

### A3 — Memory Model (M)
- Persistence mechanism declared
- Stateless skills marked as stateless

### A4 — Planning Policy (P)
- Workflow steps with clear sequence
- Preconditions and postconditions
- Error handling and recovery

### Scoring
- PASS: A1 + A2 + A4 all met
- PARTIAL: Has role spec but missing boundaries or manifest
- FAIL: No role boundaries, generic instruction

## Overall Level Calculation

- Level 3: ALL four pillars PASS
- Level 2: Secured PASS + 2 others PASS + no FAIL
- Level 1: Secured PASS/PARTIAL + max 1 FAIL
- Non-compliant: Secured FAIL or 2+ FAIL
