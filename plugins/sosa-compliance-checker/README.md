# SOSA™ Compliance Checker

Audit your Claude plugins, skills, and coding agents against the SOSA™ methodology — Supervised Orchestrated Secured Agents.

## What it does

Scans your entire plugin ecosystem and evaluates each component against the four SOSA pillars, covering both enterprise operations and AI-assisted software engineering (SOSA for Code):

1. **Supervised** — Are high-impact actions gated on human approval? Is the trust gradient active? Are code changes scored by impact (L0-L4)? Does each task maintain a living CLAUDE.md with institutional memory?
2. **Orchestrated** — Does the skill follow Plan→Act→Verify? For code: is merge serialization enforced? Are code context registries shared between planning and implementation agents? Are inline verification checkpoints running?
3. **Secured** — Are credentials safe? Are coding agents sandboxed with scoped repository permissions? Are secrets excluded from agent capability sets? Is external data scanned for prompt injection?
4. **Agents** — Is the role specification formal (R, T, M, P, K)? For coding agents: is the codebase knowledge model K populated and maintained? Are distinct roles (Planner, Implementer, Tester, Reviewer, Deployer, Monitor) enforced by the security layer?

## SOSA for Code

This checker now includes full support for auditing AI coding agent governance:

- **Graduated supervision levels** (L0 Auto → L4 Prohibited) for code changes
- **Trust gradient** assessment: agents earn autonomy through verified performance
- **Plan-Code-Verify** execution model validation
- **Codebase knowledge model (K)** coverage and currency
- **Role enforcement** across the SDLC (Planner, Implementer, Tester, Reviewer, Deployer, Monitor)
- **Living CLAUDE.md** — adaptive institutional memory updated each run

## Usage

Just say: "Run a SOSA audit", "Check SOSA compliance", "Audit my plugins", or "Check SOSA for Code compliance"

## Whitepaper

Read the full SOSA™ methodology: [SOSA™: Supervised Orchestrated Secured Agents](https://msapps-mobile.github.io/claude-plugins/sosa-whitepaper)

## No setup required

Read-only plugin — only reads skill files and configs to analyze them.
