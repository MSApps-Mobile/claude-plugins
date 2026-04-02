# SOSA Compliance Audit

## Objective
Conduct comprehensive SOSA™ (Supervised Orchestrated Secured Agents) compliance assessment across your AI operations infrastructure and software engineering workflows. This skill audits adherence to the four SOSA pillars — for both enterprise agent operations and AI-assisted code generation — and identifies remediation actions needed to achieve target compliance levels.

## Context
SOSA compliance ensures production-grade autonomous AI operations through four interdependent pillars:
- **Supervised**: Graduated human oversight calibrated to action impact
- **Orchestrated**: Coordinated multi-agent workflows with structured context sharing
- **Secured**: Zero-trust security with scoped permissions and immutable audit trails
- **Agents**: Formally specified autonomous entities with defined roles, tools, memory, and planning policies

Compliance is assessed at three levels:
- **Level 1** (70%): Basic compliance with foundational controls
- **Level 2** (85%): Intermediate compliance with enhanced monitoring and automated controls
- **Level 3** (100%): Advanced compliance with continuous monitoring and automated enforcement

## Plan Phase

### Step 1: Define Scope
- Identify target systems, plugins, skills, scheduled tasks, and code repositories
- Document audit objectives and success criteria
- Establish baseline compliance expectations
- Determine impact level (low/medium/high) per component
- Identify whether audit covers operations, code, or both domains

### Step 2: Checklist Selection
- Review SOSA compliance checklist (see `references/sosa-checklist.md`)
- Select controls relevant to the environment
- Prioritize critical vs. nice-to-have controls
- Map controls to SOSA pillars
- For code audits: include code-specific supervision levels, trust gradient, and Plan-Code-Verify controls

### Step 3: Assessment Approach
- Plan data collection methods (file scanning, config review, log analysis)
- Identify required access levels
- Define timeline and resource allocation
- Prepare stakeholder communication

## Act Phase

### Step 1: Supervised Controls Assessment

#### Operations Governance
- **Governance**: Review oversight frameworks and approval processes
- **Monitoring**: Verify human-in-the-loop mechanisms for high-impact actions
- **Audit**: Check activity logging and review procedures
- **Escalation**: Validate escalation paths and response procedures
- **Living Documentation**: Verify CLAUDE.md exists per task/agent/project and is updated each run with new learnings (adaptive institutional memory)

#### Code Supervision (SOSA for Code)
- **Impact Scoring**: Verify code changes are scored by: files modified, file criticality (infra vs UI vs docs), security-sensitive patterns (auth, crypto, data access), reversibility, blast radius (shared libs vs leaf modules)
- **Supervision Levels**: Confirm graduated review requirements are enforced:
  - L0 (Auto): Formatting, comments, docs — no review needed
  - L1 (Async): Single-file, non-critical — post-merge review
  - L2 (Pre-merge): Multi-file, business logic — 1 human reviewer
  - L3 (Gated): Security, infra, shared libs — senior + security review
  - L4 (Prohibited): Production deploy, DB migration — human-only
- **Trust Gradient**: Check that agent autonomy is adaptive — agents earn expanded autonomy through verified performance (+0.1 per successful approval, -0.5 per incident, threshold=1.0)
- **Plan Review**: Verify high-impact plans are reviewed before implementation begins (not just post-implementation code review)

### Step 2: Orchestrated Controls Assessment

#### Workflow Coordination
- **Task DAG**: Verify multi-agent workflows use directed acyclic graph scheduling with explicit data dependencies
- **Context Registries**: Check that agents share context through structured registries (not ad-hoc messages)
- **Dependency Management**: Verify inter-system dependencies are mapped and version compatibility maintained
- **State Management**: Confirm handoff procedures and state persistence between agent sessions

#### Code Orchestration (SOSA for Code)
- **Merge Serialization**: When multiple coding agents touch overlapping files, verify the orchestrator sequences merges and validates each against the current codebase state
- **Code Context Registries**: Verify planning agents write architectural decisions and interface contracts to shared registries, and implementer agents read these before writing code
- **Role Separation**: Confirm distinct agent roles are enforced — Planner, Implementer, Tester, Reviewer, Deployer, Monitor — with security-layer boundaries (a Tester cannot merge; an Implementer cannot deploy)
- **Inline Verification Checkpoints**: After each significant code change, the agent runs relevant tests and validates postconditions before proceeding

#### Platform & Efficiency
- **Platform Compliance**: Verify plugin works on both Claude Code (CLI) and Cowork (desktop) — declares platforms, handles path differences, degrades gracefully
- **Token Efficiency**: Verify agent interactions are optimized for minimal overhead — bloated systems waste context window budget

### Step 3: Secured Controls Assessment

#### Core Security
- **Authentication**: Verify identity verification mechanisms and credential management
- **Secrets Isolation**: Confirm no hardcoded credentials, API keys, or tokens in skill files or configs — agents use scoped, time-limited credentials
- **Access Control**: Review least-privilege enforcement and role-based access
- **Audit Trail**: Validate logging completeness, immutability, and retention (minimum 1 year)

#### Code Security (SOSA for Code)
- **Sandboxed Execution**: Each coding agent operates within a sandbox restricting file system access to the target repository, limiting network to approved services
- **Scoped Repository Permissions**: Each agent has a capability set specifying which repos, branches, and file paths it may read or modify — enforced at the file system level
- **Secrets Exclusion**: Environment variables, .env files, API keys, cryptographic material, and secrets management systems are excluded from agent capability sets
- **Immutable Code Audit Trail**: Every code change, file access, shell command, and external API call is logged with the reasoning chain that led to each decision
- **Prompt Injection Protection**: External data is scanned for prompt injection attempts

### Step 4: Agent Specification Assessment

#### Core Agent Controls
- **Role Specification (R)**: Verify each agent has domain boundaries, success criteria, and escalation triggers encoded in structured specs enforced by runtime
- **Tool Manifest (T)**: Confirm declared tool access matches actual capabilities — no unauthorized tools available
- **Memory/Context (M)**: Check persistence and context store across execution cycles
- **Planning Policy (P)**: Validate action selection governance

#### Code Agent Controls (SOSA for Code)
- **Codebase Knowledge Model (K)**: Verify coding agents maintain a knowledge model capturing: repository architectural patterns, dependency graph between modules, team coding standards and style guidelines, history of recent changes and active branches, known technical debt and fragility areas
- **K Population**: Confirm K is populated through automated codebase analysis at agent initialization and updated incrementally
- **K-Based Restriction**: Agents with sparse K are restricted to lower-impact tasks until their knowledge model matures
- **Role Enforcement**: Security layer prevents role boundary violations — an Implementer agent cannot trigger production deployment, a Tester agent cannot directly merge code
- **Behavioral Consistency**: Agent behavior is governed by structured role specs, not prompt templates — preventing prompt injection from altering behavior

### Step 5: Execution Model Assessment

#### Plan-Act-Verify (Operations)
- **Plan**: Agents decompose objectives into operations with preconditions and postconditions, filtered by capability set
- **Act**: Planned steps execute against real systems with logging; high-impact actions are gated
- **Verify**: Outcomes are evaluated against success criteria, feeding the trust gradient

#### Plan-Code-Verify (Software Engineering)
- **Plan**: Coding agent (Planner role) analyzes requirements against codebase knowledge model K, identifies files, interfaces, tests, and constraints. Output is a partially ordered set of code changes with preconditions/postconditions. Plans exceeding θ_code are reviewed before implementation.
- **Code**: Implementation agents execute the plan by writing code, running tests, iterating on failures. Each agent works within its scoped capability set. Orchestration layer mediates access to shared resources (build systems, test databases, staging environments). Inline verification checkpoints run relevant tests after each significant change.
- **Verify**: Full test suite passes, static analysis clean, security scanning clean, coverage meets threshold, change is consistent with K patterns, diff is within expected scope. Results feed into trust gradient: τ(Aᵢ, Rⱼ) = f(pass_rate, approval_rate, defect_rate, scope_compliance).

#### Living Documentation (Adaptive CLAUDE.md)
- **Per-Task CLAUDE.md**: Verify each task, agent, or project maintains its own CLAUDE.md that serves as living institutional memory
- **Auto-Update**: CLAUDE.md is updated at the end of each run when something new is learned — new patterns discovered, edge cases encountered, architectural decisions made, or failure modes identified
- **Knowledge Persistence**: These documents persist across sessions, ensuring agents don't repeat mistakes or re-discover known constraints
- **Supervision Record**: CLAUDE.md captures supervision decisions (what was escalated, what was approved, what was rejected) creating an evolving governance record

### Step 6: Evidence Collection
- Scan all skill files, plugin configs, and CLAUDE.md files
- Collect audit logs, trust scores, and impact registries
- Review code repository configurations (branch protection, CI/CD gates)
- Verify SOSA lint and evaluation scripts are integrated into CI
- Check for existence and currency of per-agent/per-project CLAUDE.md files

## Verify Phase

### Step 1: Finding Analysis
- Categorize findings by severity (critical/high/medium/low)
- Map findings to SOSA pillars
- Assess business impact of each finding
- Prioritize remediation actions

### Step 2: Compliance Scoring
For each pillar, calculate compliance percentage:
- **Supervised score**: (controls_met / total_supervised_controls) × 100
- **Orchestrated score**: (controls_met / total_orchestrated_controls) × 100
- **Secured score**: (controls_met / total_secured_controls) × 100
- **Agents score**: (controls_met / total_agent_controls) × 100
- **Overall score**: weighted average (equal weights by default)

Level determination:
- Level 1: Overall ≥ 70%, no pillar below 50%
- Level 2: Overall ≥ 85%, no pillar below 70%
- Level 3: Overall = 100%

### Step 3: Remediation Planning
- Develop action plans for each finding
- Estimate remediation effort and timeline
- Identify resource requirements
- Assign ownership and accountability

### Step 4: Report Generation
- Summarize current compliance posture with per-pillar scores
- Detail findings organized by pillar and severity
- Provide remediation roadmap with quick wins highlighted
- Include SOSA for Code specific findings (supervision levels, trust gradient, K model) when applicable
- Note CLAUDE.md currency and coverage

### Step 5: Continuous Improvement
- Schedule follow-up assessments
- Monitor remediation progress
- Update compliance baselines
- Iterate based on lessons learned
- Verify CLAUDE.md files are being updated each run

## Success Criteria
- All critical findings addressed
- Compliance level improvement demonstrated
- Stakeholder acceptance of remediation plan
- Audit trail documenting assessment and findings
- Per-agent/per-project CLAUDE.md files exist and are current
