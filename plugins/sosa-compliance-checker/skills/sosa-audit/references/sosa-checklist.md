# SOSA Compliance Checklist

This checklist covers both enterprise operations and software engineering (SOSA for Code) controls. Items marked with `[CODE]` are specific to AI coding agent governance.

## Supervised Controls

### Governance Framework
- [ ] Written AI governance policies documented
- [ ] Executive oversight committee established
- [ ] Approval workflows for AI operations defined
- [ ] Decision authority clearly assigned
- [ ] Policy review schedule established

### Human Oversight
- [ ] Human-in-the-loop mechanisms implemented
- [ ] Escalation procedures defined for high-impact decisions
- [ ] Override capabilities available to supervisors
- [ ] Real-time notification of significant agent actions
- [ ] Manual review requirements documented

### Activity Monitoring
- [ ] Centralized logging system operational
- [ ] Agent actions tracked and timestamped
- [ ] Audit trail immutable and tamper-evident
- [ ] Log retention policy (minimum 1 year) defined
- [ ] Access to logs restricted to authorized users

### Incident Response
- [ ] Incident response team identified
- [ ] Response procedures documented
- [ ] Escalation contact list maintained
- [ ] Post-incident reviews conducted
- [ ] Root cause analysis documented

### Impact Scoring & Trust Gradient
- [ ] Impact scoring function defined (magnitude, visibility, reversibility, sensitivity)
- [ ] Risk threshold θ configured per organization/department
- [ ] Actions below θ execute autonomously; above θ gated on approval
- [ ] Trust gradient implemented: +0.1 per successful approval, -0.5 per incident
- [ ] Trust threshold (default 1.0) triggers autonomy expansion
- [ ] Agents with failure patterns are automatically escalated to tighter supervision

### Living Documentation (Adaptive CLAUDE.md)
- [ ] Per-task/agent/project CLAUDE.md exists
- [ ] CLAUDE.md is updated at end of each run with new learnings
- [ ] CLAUDE.md captures supervision decisions (escalated, approved, rejected)
- [ ] CLAUDE.md records discovered patterns, edge cases, and failure modes
- [ ] CLAUDE.md persists across sessions as institutional memory
- [ ] CLAUDE.md is reviewed during plan phase of subsequent runs

### `[CODE]` Graduated Code Supervision
- [ ] Code impact score I(c) computed from: files modified, file criticality, security patterns, reversibility, blast radius
- [ ] L0 (Auto): Formatting/comments/docs — no review required
- [ ] L1 (Async): Single-file non-critical — post-merge review
- [ ] L2 (Pre-merge): Multi-file business logic — 1 human reviewer before merge
- [ ] L3 (Gated): Security/infra/shared libs — senior + security review
- [ ] L4 (Prohibited): Production deploy/DB migration — human-only execution
- [ ] Plan review: High-impact plans reviewed before implementation begins
- [ ] Trust gradient operates per-agent per-repository

## Orchestrated Controls

### Workflow Coordination
- [ ] Multi-agent workflows documented
- [ ] Task dependencies mapped as directed acyclic graph (DAG)
- [ ] Sequencing rules enforced
- [ ] Handoff procedures defined
- [ ] State management implemented

### Context Sharing
- [ ] Context shared via structured registries (not ad-hoc messages)
- [ ] Decoupled architecture: upstream context survives downstream failures
- [ ] Structured output formats (JSON, not free-text) for inter-agent data
- [ ] Context records include provenance (which agent, when, why)

### Task Routing
- [ ] Agent capabilities documented
- [ ] Task assignment logic documented
- [ ] Load balancing implemented
- [ ] Priority queue management
- [ ] Task tracking system operational

### Dependency Management
- [ ] Inter-system dependencies mapped
- [ ] API contracts defined and validated
- [ ] Version compatibility verified
- [ ] Backward compatibility maintained
- [ ] Breaking changes documented

### Token Efficiency (O6)
- [ ] Agent interactions optimized for minimal overhead
- [ ] Prompt compression applied where applicable
- [ ] Context window usage monitored
- [ ] Batch processing used for repetitive tasks
- [ ] Model selection appropriate to task complexity

### Platform Compliance (Claude Code + Cowork)
- [ ] Plugin declares supported platforms in plugin.json
- [ ] Skill works in headless mode (Claude Code CLI) without GUI dependencies
- [ ] Skill works in interactive mode (Cowork desktop)
- [ ] File paths are platform-aware (sandbox vs local)
- [ ] MCP tools available on both platforms or gracefully degrade
- [ ] Platform-specific features declared as optional with fallback

### Resilience & Recovery
- [ ] Failover mechanisms implemented
- [ ] Recovery time objectives (RTO) defined
- [ ] Recovery point objectives (RPO) defined
- [ ] Backup and restore procedures tested
- [ ] Disaster recovery plan documented

### `[CODE]` Multi-Agent Development Coordination
- [ ] Merge serialization: orchestrator sequences merges for overlapping files
- [ ] Code context registries: planning agents write architectural decisions and interface contracts
- [ ] Implementer agents read context registry before writing code
- [ ] Testing agents read implementation details to generate meaningful tests
- [ ] Structured context sharing prevents fragmentation from independent agent assumptions
- [ ] Inline verification checkpoints: agent runs relevant tests after each significant code change

### `[CODE]` Agent Role Enforcement
- [ ] Distinct roles defined: Planner, Implementer, Tester, Reviewer, Deployer, Monitor
- [ ] Roles enforced by security layer (not just labels)
- [ ] Tester agents independent from Implementer agents (separation of concerns)
- [ ] Reviewer agents escalate ambiguous architectural decisions to humans
- [ ] Deployer agents operate at L3-L4 supervision
- [ ] Monitor agents: diagnostic actions L0-L1, remediation actions L3

## Secured Controls

### Authentication & Authorization
- [ ] Multi-factor authentication required
- [ ] Service account credentials managed securely
- [ ] API key rotation implemented
- [ ] Least privilege principle applied
- [ ] Role-based access control (RBAC) enforced

### Data Protection
- [ ] Data encryption in transit (TLS 1.2+)
- [ ] Data encryption at rest (AES-256 minimum)
- [ ] Key management procedures documented
- [ ] Sensitive data masking in logs
- [ ] Data retention policies enforced

### Network Security
- [ ] Network segmentation implemented
- [ ] Firewalls configured with least privilege rules
- [ ] VPN/private network used for sensitive connections
- [ ] DDoS protection measures in place
- [ ] Intrusion detection system operational

### Compliance & Audit
- [ ] Regular security assessments conducted
- [ ] Penetration testing performed (annually)
- [ ] Vulnerability scanning automated
- [ ] Security patch management process
- [ ] Compliance certifications obtained

### Prompt Injection Protection
- [ ] External data scanned for injection attempts
- [ ] Input validation on all agent inputs
- [ ] Agent behavior governed by structured role specs (not prompt templates)
- [ ] Tool manifests prevent unauthorized tool access regardless of prompt content

### `[CODE]` Code-Specific Zero Trust
- [ ] Sandboxed execution: coding agents restricted to target repository file system
- [ ] Network access limited to approved services (package registries, docs, CI systems)
- [ ] Scoped repository permissions: capability set per agent specifying repos, branches, file paths
- [ ] Frontend agent cannot modify backend infra (enforced at file system level)
- [ ] Secrets isolation: .env files, API keys, cryptographic material excluded from agent capability set
- [ ] Agents use scoped, time-limited credentials for service access
- [ ] Immutable code audit trail: every code change, file access, shell command, API call logged
- [ ] Audit trail captures reasoning chain behind each implementation decision
- [ ] MCP versions pinned for reproducibility

## Agent Autonomy Controls

### Role Specification (R)
- [ ] Decision boundaries clearly defined
- [ ] Autonomy levels documented
- [ ] Exception handling procedures
- [ ] Constraint enforcement validated
- [ ] Boundary testing completed
- [ ] Success criteria and escalation triggers encoded in structured specs

### Tool Manifest (T)
- [ ] Authorized tools explicitly declared in agent manifest
- [ ] Tools verified before every invocation
- [ ] No tool inheritance from orchestrator or peer agents
- [ ] Tool access matches role requirements (no excess)

### Memory & Context (M)
- [ ] Agent instructions comprehensive and clear
- [ ] Instruction version control implemented
- [ ] Knowledge base accuracy verified
- [ ] Context window optimization applied
- [ ] Cross-session persistence where needed

### Planning Policy (P)
- [ ] Action selection governance defined
- [ ] Plan decomposition follows capability constraints
- [ ] Plans are reviewable artifacts
- [ ] Preconditions and postconditions explicit

### Guardrails & Safety
- [ ] Input validation implemented
- [ ] Output validation implemented
- [ ] Instruction injection protection
- [ ] Rate limiting configured
- [ ] Safety threshold monitoring

### Performance & Monitoring
- [ ] Agent performance metrics defined
- [ ] Success rate monitoring active
- [ ] Error rate tracking implemented
- [ ] Latency monitoring configured
- [ ] Cost per operation tracked

### `[CODE]` Codebase Knowledge Model (K)
- [ ] K captures repository architectural patterns and conventions
- [ ] K includes dependency graph between modules
- [ ] K contains team coding standards and style guidelines
- [ ] K records history of recent changes and active branches
- [ ] K identifies known technical debt and areas of fragility
- [ ] K is populated through automated codebase analysis at agent initialization
- [ ] K is updated incrementally as agent observes changes
- [ ] Agents with sparse K restricted to lower-impact tasks
- [ ] K quality correlates with expanded autonomy

### `[CODE]` Plan-Code-Verify Execution Model
- [ ] Plan phase: Planner analyzes requirements against K, identifies files, interfaces, tests, constraints
- [ ] Plan output: partially ordered set of code changes with preconditions/postconditions
- [ ] Plans exceeding θ_code are subject to human review before implementation
- [ ] Code phase: Implementer writes code within scoped capability set
- [ ] Code phase: Orchestration mediates access to shared resources (build systems, test DBs, staging)
- [ ] Code phase: Inline verification checkpoints after each significant change
- [ ] Code phase: Local recovery loop on checkpoint failure (alternative implementations, K consultation, escalation)
- [ ] Verify phase: Full test suite passes
- [ ] Verify phase: Static analysis produces no new warnings
- [ ] Verify phase: Security scanning detects no new vulnerabilities
- [ ] Verify phase: Code coverage meets or exceeds repository threshold
- [ ] Verify phase: Change consistent with architectural patterns in K
- [ ] Verify phase: Diff within expected scope (scope creep triggers escalation)
- [ ] Verify results feed into trust gradient: τ(Aᵢ, Rⱼ) = f(pass_rate, approval_rate, defect_rate, scope_compliance)

## Compliance Levels

### Level 1: Basic Compliance
**Minimum 70% of checklist items completed, no pillar below 50%**
- Core oversight mechanisms
- Basic logging and monitoring
- Essential security controls
- Documented procedures
- CLAUDE.md exists for active agents/tasks

### Level 2: Intermediate Compliance
**Minimum 85% of checklist items completed, no pillar below 70%**
- Enhanced monitoring and alerting
- Automated security controls
- Regular compliance reviews
- Incident response testing
- Trust gradient active and calibrated
- CLAUDE.md updated each run with learnings
- `[CODE]` Supervision levels L0-L3 enforced

### Level 3: Advanced Compliance
**100% of checklist items completed**
- Continuous compliance monitoring
- Automated policy enforcement
- Comprehensive audit automation
- Proactive threat detection
- Full trust gradient with adaptive autonomy
- `[CODE]` Complete Plan-Code-Verify with codebase knowledge model K
- `[CODE]` All agent roles enforced with security-layer boundaries
- Living CLAUDE.md with complete supervision history

## Assessment Notes
- Review date: [FILL IN]
- Assessment scope: [FILL IN]
- Compliance level target: [FILL IN]
- Findings summary: [FILL IN]
- Remediation timeline: [FILL IN]
