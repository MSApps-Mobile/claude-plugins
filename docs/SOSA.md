# SOSA™ — Supervised Orchestrated Secured Agents

**A Methodology for Production-Grade Autonomous AI Operations**

By [Michal Shatz](mailto:michal@msapps.mobi), MSApps Research, March 2026

---

## Overview

SOSA™ (Supervised Orchestrated Secured Agents) is a four-pillar methodology that reconciles agent autonomy with organizational accountability. It provides a formal structure for deploying multi-agent systems that operate continuously, adapt to heterogeneous toolchains, and maintain verifiable compliance with security and governance policies.

All MSApps plugins are built to be **SOSA-compliant**, meaning they implement the four pillars at the plugin level.

> **Read the full whitepaper:** [sosa-whitepaper.pdf](sosa-whitepaper.pdf)
> **See the live framework page:** [opsagents.agency/sosa](https://opsagents.agency/sosa)

---

## The Four Pillars

### 1. Supervised

Every agent operates under a defined supervision policy. Supervision is graduated: routine, low-impact tasks execute autonomously, while high-stakes actions require explicit human approval.

**How MSApps plugins implement this:**
- Each plugin declares its **impact level** (low / medium / high) in plugin metadata
- Low-impact plugins (read-only, local cleanup) operate fully autonomously
- Medium-impact plugins (sending messages, modifying data) include confirmation checkpoints
- High-impact plugins (financial operations, bulk outreach) require human approval before execution
- The **trust gradient** means autonomy is earned by verified behaviour, per class of action. Today the widening is done by people reading the record, not by a computed score (see [Trust doctrine](#trust-doctrine-autonomy-is-earned))

### 2. Orchestrated

Agents coordinate through structured registries and a DAG (directed acyclic graph) execution model, not ad-hoc message passing. **Orchestration demands efficiency** — an orchestrated system that wastes resources on redundant work, bloated context, or duplicate components is poorly orchestrated by definition.

**How MSApps plugins implement this:**
- Plugins declare their **dependencies** (which MCP servers, connectors, or other plugins they require)
- Plugins use the **Plan → Act → Verify** execution loop
- Context is shared through structured outputs (JSON, structured reports), not free-text handoffs
- Scheduled tasks declare temporal dependencies and execution order
- Plugin outputs feed into downstream workflows through well-defined interfaces
- **Token efficiency** is enforced as a first-class orchestration concern:
  - Skill descriptions are kept lean — every word costs tokens across every session
  - Shared rules and changing data are externalized to structured stores (Notion, config files), not duplicated across skills
  - Unused MCP connectors and duplicate plugins are eliminated — idle tools waste context budget
  - Scheduled task frequency matches the actual cadence of change, not an arbitrary interval
  - The [`token-efficiency-audit`](../plugins/token-efficiency-audit) plugin provides automated auditing and optimization of token usage across the entire system
- **Platform compliance** is enforced — every plugin must work correctly in both Claude Code (CLI) and Cowork (desktop) environments, declaring supported platforms and handling platform-specific differences gracefully

**Platform compliance is an orchestration requirement:**
An orchestrated plugin must be compliant with the platforms it runs on. For the SOSA ecosystem, this means every plugin and skill must be **Claude Code compliant** and **Cowork compliant**. A plugin that only works in one environment but fails or degrades in the other is not properly orchestrated — it breaks the coordination contract. Specifically:
- Plugins must declare their supported platforms in `plugin.json` (`"platforms": ["claude-code", "cowork"]`)
- Skills must work correctly in both headless (Claude Code CLI) and interactive (Cowork desktop) modes
- File paths, tool availability, and user interaction patterns differ between platforms — skills must handle both gracefully
- MCP tools used by the skill must be available or gracefully degradable on both platforms
- Skills that require platform-specific features (e.g., computer use, Chrome extension) must declare this and provide fallback behavior for the other platform

**Why efficiency is an orchestration concern:**
A multi-agent system's context window is a shared finite resource. Every token consumed by a bloated skill description, a redundant MCP connector, or a duplicate plugin is a token unavailable for actual work. True orchestration means not just coordinating what agents do, but ensuring the infrastructure that supports them — system prompts, tool definitions, scheduled executions — operates at minimum viable cost. An agent system that wastes 30% of its context window on unused tool definitions is as poorly orchestrated as one with race conditions between concurrent tasks.

### 3. Secured

Security is not a perimeter — it is a property of every layer. The aim is that each agent runs with scoped credentials and clear boundaries, and that its actions can be audited. This is a design principle for plugin authors; it is not a certification or a guarantee about any plugin.

**How MSApps plugins implement this:**
- Credentials are **never hardcoded** in skill files — they live in local config files or environment variables
- Each plugin declares its **capability set** (which tools and APIs it can access)
- Plugin authors are expected to treat external data as untrusted and guard against **prompt injection**; this repository does not scan for it (see [SECURITY.md](../SECURITY.md) for what is and is not checked)
- Pinning MCP server package versions is recommended practice to limit supply-chain risk; it is not enforced here
- Logging plugin actions is up to each plugin; there is no repository-wide action log
- Plugins follow the **principle of least privilege** — they only access what they need

### 4. Agents

SOSA agents are goal-directed autonomous entities defined as a tuple **A = (R, T, M, P)**:
- **R** — Role specification (domain boundaries, success criteria, escalation triggers)
- **T** — Tool manifest (authorized APIs, databases, communication channels)
- **M** — Memory and context store (persistence across execution cycles)
- **P** — Planning policy (how actions are selected given state and objectives)

**How MSApps plugins implement this:**
- Each plugin's `SKILL.md` defines the **role specification** (what the plugin does, when it triggers, what it should never do)
- The `.mcp.json` and connector requirements define the **tool manifest**
- Plugins that need memory use structured stores (Notion, Google Calendar, local config files)
- Planning is governed by the skill instructions, which define step-by-step workflows with explicit preconditions and postconditions

---

## The Execution Model: Plan → Act → Verify

Every SOSA-compliant plugin follows a three-phase execution loop:

1. **Plan** — Decompose the objective into a sequence of tool calls, subject to the capability set constraints. Filter out actions that would violate domain boundaries. **Assess resource cost** — if the plan would consume excessive tokens, context, or executions, optimize before proceeding.

2. **Act** — Execute each planned step against real external systems, with every interaction logged. Actions that exceed the impact threshold are paused and escalated.

3. **Verify** — Evaluate the outcome against declared success criteria. Produce a structured evaluation record that feeds into the trust gradient. **Measure efficiency** — compare actual token/resource consumption against expected cost.

---

## Trust doctrine: autonomy is earned

> **Autonomy is earned by trust.** It is granted per class of action, on evidence, under a ceiling set by risk, and withdrawn when the evidence regresses. The same rule binds human and AI agents.

Nobody gives a new engineer production keys on their first morning. That isn't distrust; there is simply no evidence yet. SOSA treats an AI agent the same way. Autonomy is **architected, not prompted**: it is enforced by the gateway and the gates, not requested of the model. The customer chooses the level: **if you wish, nothing ships without your approval.**

The full argument, with sources, is in the OpsAgents AI white paper *Autonomy is earned by trust* (draft, 2026-10-16).

### The trust ladder

Each actor, human or AI, holds one step **per class of action** (for example: edit docs, merge to an internal repo, deploy to production, send a client message, move money).

| Step | The actor may | The human |
|---|---|---|
| **T0 · Suggest** | Gather, analyse, propose. Change nothing. | Decides and acts |
| **T1 · Act with approval** | Prepare the change; execute after a yes | Approves each action |
| **T2 · Act, then report** | Execute through gates; the record is reviewed after | Reviews; can reverse |
| **T3 · Act within an envelope** | Execute inside declared limits; logged and stoppable | Sets the envelope; holds the stop |

Rules:
- **There is no step above T3.** Nothing acts while ignoring the human. Every step is designed to keep a log and a stop; log completeness is not yet measured.
- **People decide promotion today**, by reading the record on that class of action.
- **Demotion is immediate** on a regression, a gate breach or a false green.
- **The customer can hold code changes at T1**: a hold on the ticket stops the merge gate. Other classes are agreed per project.
- **Some acts never leave T1** in our fleet: sending money, cold outreach to new contacts, credentials only a person holds, and spend beyond budget.

### The ceiling: supervision levels

Trust moves an actor up the ladder. Risk (the impact score: magnitude, external visibility, reversibility, sensitivity) caps how far it can go:

| Supervision level | Highest ladder step |
|---|---|
| L0 Auto | T3 |
| L1 Async | T2 |
| L2 Pre-merge | T1 |
| L3 Gated | T1, with a domain reviewer |
| L4 Prohibited | T0 (a human executes) |

**Practice note.** Since 2026-08-24, production deploys on OpsAgents AI's **own internal repositories** run automatically, and only when four evidence legs hold: front-end QA, back-end QA, a CTO-agent review on the latest commit, and a production sanity check after deploy with revert on regression. Client projects are decided case by case.

### Mapping: controls, NIST trust characteristics, ladder

This is **our own reading, not a compliance or alignment claim.** It has not been reviewed by a qualified third party. *NISTIR 8332* (draft, 2021) was withdrawn by NIST on 2023-01-04 and is used only as vocabulary. The *AI RMF 1.0* is voluntary and under revision.

| Control (pillar) | NISTIR 8332 draft | AI RMF 1.0 | Ladder role | Status |
|---|---|---|---|---|
| Builder ≠ reviewer; a pipeline agent cannot move its own work to deploy (S) | Objectivity, Accountability | Accountable & transparent | Precondition for T1+ | Measured 2026-10-12 |
| Approval counts only on the exact commit being merged (S) | Reliability, Accountability | Valid & reliable | Gate for T1/T2 merges | Measured |
| Isolation gate + builder stamps (S) | Objectivity | Valid & reliable | Gate for T2 | In use since the 2026-10-15 ruling |
| Merge gate fails closed: unclean isolation, no approval at head, or missing tooling ⇒ refuse (S) | Safety, Resiliency | Safe; Secure & resilient | Keeps T2 honest | Measured 2026-10-15 |
| A human gate label on the ticket halts the merge (S) | Accountability | Accountable & transparent | The customer's T1 pin | Measured |
| Four-leg production bar (S) | Accuracy, Reliability, Safety | Valid & reliable; Safe | T3 envelope, internal deploys | Ruled 2026-08-24; no deploy-path deny event on record |
| Human-only acts (S) | Safety, Accountability | Safe; Accountable | Hard ceiling at T1 | Doctrine |
| Gateway: deny-list + credentials held server-side (Sec) | Security, Privacy | Secure & resilient; Privacy-enhanced | Caps blast radius at every step | Measured; not every rail is gateway-only yet |
| Role spec + capability set (A) | Security, Safety | Secure & resilient | Bounds every step | Method (white paper §4); runtime enforcement not measured |
| Claim protocol + fan-out cap (O) | Reliability, Resiliency | Valid & reliable | Coherent parallel work | Measured 2026-10-12 |
| Audit trail on the ticket (Sec) | Explainability, Accountability | Accountable & transparent; Explainable | The evidence promotion reads | Partial: completeness not measured; not immutable |
| Domain reviewers: a security review and an accessibility review, each to run in a fresh context; blocking findings to block the merge (S) | Security, Safety, Objectivity | Secure & resilient; Safe | Raises reviewer expertise (axis B) | In rollout, ruled 2026-10-16 |
| Trust rating (S) | Objectivity, Explainability | Accountable & transparent | Future input to promotion | In build; changes no permission today |

### Trust rating (in build)

A deterministic score per subject (**agent, human, skill, system**) **per class of action**. It will be computed by code, so the same inputs always give the same score, and every score will list the factors that moved it. Inputs:

1. **Actor level**: declared weights in a versioned config (human levels such as owner, senior, employee, client approver; agent levels such as model tier, role and lane).
2. **Isolation**, on two axes (below).
3. **Track record**, time-decayed: merged vs reworked changes, gate breaches, false greens, reverts, CI pass rate.
4. **Reversibility and blast radius** of the action being trusted.

**Isolation has two axes.** The working theory is *same-context pollution*: a reviewer that shares the builder's context tends to confirm what the builder believed.

| A · Context isolation (what the reviewer saw) | B · Reviewer diversity (who reviews) |
|---|---|
| A0 same session as the builder | B0 same model, same prompt or skill |
| A1 same checkout or worktree | B1 same model, different role prompt |
| A2 new session, same machine, fed the builder's transcript or summary | B2 different model tier, same vendor |
| A3 fresh session, sees only the diff + spec | B3 different vendor or model family |
| A4 fresh session that writes its own tests or repro before reading the builder's claims | B4 a human with domain knowledge (also track-record-weighted) |

Trust from isolation = f(A, B). A human who only reads the agent's summary (**A2 + B4**) can be weaker evidence than a different-vendor model at **A4 + B3**. Neither axis settles it alone.

Guards: **publish the method, never individual scores.** Human scores are internal, never used for HR decisions. Unmeasured inputs stay UNMEASURED, never defaulted to good. Weights are a config the owner can change.

### Evidence from our own gates

- **2026-09-10:** our pipeline guard was found **failing open**. It was armed with a timestamp in seconds but compared in milliseconds, so it judged its own state stale and allowed every move. The fix merged on 2026-09-13; the installed hook was proved to block on 2026-09-15.
- **2026-10-07:** a merge went through 30 minutes after a human put a "do not merge" label on its ticket. The merge gate now reads the ticket's live gate labels; unreadable labels count as blocked.
- **2026-10-12:** the re-armed guard blocked a forbidden move (rc=2) and allowed a permitted one (rc=0).
- **2026-10-15:** two pull requests merged past our gates. One merged while the isolation gate said HOLD. The other, a security fix, merged at 18:31:45Z with only a COMMENTED review; the approval came at 18:37:40Z. The fail-closed merge-gate fix was merged at 19:56:48Z the same evening. Both heads carry a CTO-agent approval (#13 before its merge, #14 six minutes after); nothing was reverted.

The common shape: the rule existed but was not in the path. Each fix moved it from operator discipline into a control that fails closed, then proved the control both ways.

### Install the plugins

Get SOSA: the SOSA plugins are free to install in Claude, at *Settings → Plugins → Marketplaces → Add →* `MSApps-Mobile/claude-plugins`.

### What this section does not claim

No certification (SOC 2, ISO or other), no audit, no penetration test. No compliance or alignment with NIST, ISO/IEC 42001 or the EU AI Act. The EU AI Act's human-oversight article (Art. 14) applies to high-risk systems from 2 Dec 2027 / 2 Aug 2028, as amended by Reg. (EU) 2026/1744. No computed trust score changes a permission yet. The audit store is not immutable.

---

## SOSA Compliance Levels

| Level | Requirements | Example Plugins |
|-------|-------------|-----------------|
| **Level 1 — Basic** | Role spec in SKILL.md, pinned dependencies, no hardcoded secrets | — |
| **Level 2 — Standard** | Level 1 + prompt injection handling, audit logging, declared capability set, token-efficient skill design | — |
| **Level 3 — Full** | Level 2 + human approval gates for high-impact actions, structured Plan→Act→Verify loop, trust gradient, system-level efficiency auditing | — |

These levels are the requirements a plugin author declares and aims for. This repository does not verify them, and no plugin is certified at any level, so no example plugins are listed. What CI actually runs (`.github/workflows/`, see also [SECURITY.md](../SECURITY.md)):

- **`sosa-lint.yml`** — on every pull request to `main`, every push to `main`, and on manual/`release.yml` dispatch:
  - `scripts/sosa-lint.sh`: per plugin (it also checks `skills/*` and `scheduled-tasks/*` directories, with a broader `api_key` pattern for skills), fails if no `SKILL.md` exists, if a `SKILL.md` contains none of the words *trigger*, *when to use*, *use this skill* or *description*, if a `api_key=`/`apiKey:`/`password=`/long `token=` assignment with a quoted value is found, or if a `.env` (or `.env.local`/`.production`/`.staging`/`.development`) file is committed. It only warns on a `SKILL.md` over 2,000 words, a missing manifest, or a missing README.
  - a repo-wide grep for `api_key=` and `password=` assignments and committed `.env` files;
  - a check that every plugin directory contains a `SKILL.md`;
  - a word-count check that only **warns** on a `SKILL.md` over 3,000 words;
  - `scripts/sosa-eval.sh --ci`: a keyword score per plugin (for example, the word *confirm* or *approval* anywhere in its Markdown earns the "approval gates" point). It fails only if a plugin (or a `skills/*`, `scheduled-tasks/*` or `agents/*` item) scores below 70%. The "Level" it prints is this keyword score, **not** the compliance levels in the table above.
- **`validate-pr.yml`** — on pull requests to `main` that touch `plugins/`, `scripts/` or `.claude-plugin/`: for each changed plugin, a structure check (`.claude-plugin/plugin.json` and a `SKILL.md` present), a `plugin.json` check (required fields, semver version), a `SKILL.md` frontmatter check, a secret-pattern scan and a dry-run package build; repo-wide, the same `sosa-lint.sh` and `sosa-eval.sh --ci` runs and a check that `.claude-plugin/marketplace.json` lists every plugin directory (with a test proving that check can fail).
- **`release.yml`** — on pushes to `main` that touch `plugins/`: bumps the changed plugins' patch versions, packages them, tags a GitHub release, and dispatches `sosa-lint.yml` on the new `main` head. Its only check is a structure check; it runs no security checks.

Pinned dependencies, prompt injection handling, audit logging and human approval gates are not checked by any of these. All of them are pattern matches, and because branch protection is not enabled on `main`, a failing check does not block a merge.

---

## SOSA Infrastructure Plugins

These plugins enforce SOSA compliance across the system:

| Plugin | Pillar Focus | Purpose |
|--------|-------------|---------|
| [`sosa-compliance-checker`](../plugins/sosa-compliance-checker) | All four pillars | Audits all installed plugins and skills against the SOSA checklist, generates compliance reports, and offers to fix gaps |
| [`token-efficiency-audit`](../plugins/token-efficiency-audit) | Orchestrated (efficiency) | Audits and optimizes token usage across skills, scheduled tasks, plugins, and MCP connectors. Enforces the efficiency dimension of the Orchestrated pillar |

The `sosa-compliance-checker` runs the `token-efficiency-audit` as part of its Orchestrated pillar assessment. Together, they ensure the system is both compliant and efficient.

---

## Reference Implementation

[OpsAgents AI](https://opsagents.agency) runs its own agent fleet under the SOSA methodology. The framework is presented as a live, citable page — with a real production audit-log proof — at **[opsagents.agency/sosa](https://opsagents.agency/sosa)**.

---

© 2026 MSApps Research. All rights reserved.
