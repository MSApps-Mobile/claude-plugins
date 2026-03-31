# SOSA™: Supervised Orchestrated Secured Agents

**A Methodology for Production-Grade Autonomous AI Operations and Software Engineering**

Michal Shatz — MSApps Research — [michal@msapps.mobi](mailto:michal@msapps.mobi)

March 2026

---

## Abstract

The rapid proliferation of large language model (LLM)-based agents in enterprise workflows and software engineering has exposed a critical gap: the absence of a unifying framework that governs how autonomous agents should be supervised, coordinated, and constrained in production environments. Whether these agents automate business operations or generate production code, existing approaches treat autonomy and control as opposing forces, resulting in systems that are either too brittle to scale or too opaque to trust. We propose SOSA™ — Supervised Orchestrated Secured Agents — a four-pillar methodology that reconciles agent autonomy with organizational accountability. SOSA provides a formal structure for deploying multi-agent systems that operate continuously across both operational and engineering domains, adapt to heterogeneous toolchains, and maintain verifiable compliance with security and governance policies. This paper presents the unified SOSA methodology and demonstrates its applicability to both enterprise automation and AI-assisted software development.

**Keywords:** AI agents, multi-agent systems, enterprise automation, agent governance, orchestration, human-in-the-loop, zero-trust security, production AI, LLM operations, AI coding agents, software engineering automation, code generation governance, SDLC automation

---

## 1. Introduction

The transition of AI agents from research demonstrations to production deployments represents one of the most consequential shifts in enterprise technology since the advent of cloud computing. Large language models equipped with tool-use capabilities and persistent context now possess the capacity to automate complex workflows that previously required dedicated human staff — from lead qualification and financial reconciliation to code generation, testing, and deployment.

Yet the vast majority of enterprise agent deployments fail. Industry estimates suggest that fewer than 15% of AI agent pilot programs survive to sustained production use. The failure modes are predictable and systematic across both operational and engineering domains.

The first failure mode is **under-autonomy**: agents configured as elaborate chatbots, requiring human input at every decision point, producing marginal efficiency gains at high interaction costs. In software engineering, over-governed coding agents require approval at every file write, reducing them to expensive autocomplete engines. The human operator becomes a bottleneck, and the promised automation benefits evaporate.

The second failure mode is **over-autonomy**: agents deployed with insufficient guardrails that produce cascading errors, hallucinate business-critical actions, or silently drift from their intended objectives. In the coding domain, under-governed agents produce code that passes tests but violates team conventions, introduces dependency sprawl, or implements expedient solutions that create mounting maintenance burdens. A single unguarded agent can propagate vulnerable patterns across dozens of endpoints in a single session — code that is syntactically correct, passes unit tests, and satisfies functional requirements while containing subtle security flaws.

Both failure modes stem from the same root cause: the absence of a structured methodology for calibrating the supervision-autonomy spectrum. Organizations lack a principled framework for determining which tasks an agent should handle independently, which require human oversight, and how multiple agents should coordinate without creating brittle dependencies or security vulnerabilities.

This paper introduces **SOSA™ — Supervised Orchestrated Secured Agents** — a four-pillar methodology designed to bridge this gap across both enterprise operations and software engineering.

---

## 2. Related Work

### 2.1 Multi-Agent Frameworks

The emergence of multi-agent architectures has produced several notable frameworks. Microsoft's AutoGen [1] introduces conversable agents that coordinate through structured dialogue patterns. CrewAI [2] emphasizes role-based agent design with sequential and hierarchical task delegation. LangGraph [3] provides a stateful, graph-based orchestration layer built atop LangChain. Each framework addresses coordination mechanics but treats supervision, security, and governance as application-level concerns rather than framework-level primitives. SOSA integrates these dimensions into the core architecture.

### 2.2 Reasoning and Execution Patterns

The ReAct paradigm [4] demonstrated that interleaving reasoning traces with tool-use actions significantly improves agent reliability. Plan-and-Execute architectures [5] separate high-level planning from step-wise execution, enabling more robust error recovery. Reflexion [6] introduced self-reflective agents that learn from execution failures. SOSA's Plan-Act-Verify loop extends these patterns by adding an explicit verification phase with organizational feedback loops and a formal trust gradient.

### 2.3 AI Coding Assistants and Agents

The evolution from code completion to coding agents has occurred in distinct phases. GitHub Copilot [7] demonstrated that LLM-based code suggestion could achieve broad developer adoption, but operated as a reactive tool embedded within the editor. Cursor and Windsurf extended this model with multi-file editing capabilities and conversational interfaces, but retained the human-in-the-loop at every edit boundary. Claude Code [8] and Devin [9] represent the agentic frontier: systems that accept high-level task descriptions and autonomously plan, implement, test, and iterate. These tools possess genuine autonomy — they make architectural decisions, choose implementation strategies, and recover from errors without human guidance at each step. None of these systems, however, embed governance as a first-class concern. Autonomy boundaries are configured through ad-hoc permission flags rather than through a principled framework that considers impact magnitude, reversibility, and organizational risk tolerance.

### 2.4 Enterprise AI Governance

The NIST AI Risk Management Framework [10] provides comprehensive guidelines for AI system governance but does not address the specific challenges of autonomous agent deployments. The EU AI Act [11] establishes risk-based classification for AI systems, with high-risk categories requiring human oversight and transparency — principles that SOSA operationalizes through its Supervised and Secured pillars. ISO/IEC 42001 [12] defines requirements for AI management systems but remains abstract regarding multi-agent coordination. SOSA translates these regulatory intentions into concrete architectural patterns.

### 2.5 Trust and Safety Frameworks

Capability-based security [13] provides a theoretical foundation for fine-grained access control that SOSA adopts for agent permission management. The principle of least privilege, when applied to AI agents, demands that each agent possesses only the credentials and tool access necessary for its defined role — a requirement that most existing frameworks honor in documentation but not in enforcement. Zero-trust architecture principles [14] inform SOSA's inter-agent communication model, where every message requires mutual attestation regardless of network topology.

### 2.6 DevOps and CI/CD Automation

The DevOps movement established that software delivery pipelines benefit from automation at every stage: build, test, deploy, monitor [15]. CI/CD platforms automate deterministic workflows triggered by code events. However, these systems execute fixed scripts — they do not reason, adapt, or make judgment calls. The introduction of AI agents into the SDLC creates a fundamentally different automation paradigm: agents that make non-deterministic decisions about code structure, implementation strategy, and error recovery. Existing CI/CD governance models — pipeline approvals, environment protections, deployment gates — were designed for deterministic automation and are insufficient for governing adaptive, reasoning agents.

---

## 3. The Problem: Ungoverned Agents

Before presenting the SOSA framework, we characterize the specific failure modes that motivate the need for a governance methodology. These failure modes manifest differently in operational and engineering contexts but share structural similarities.

### 3.1 Silent Drift and Technical Debt Accumulation

Operational agents without persistent architectural awareness treat each execution session as independent. Over time, the cumulative effect of locally reasonable but globally uncoordinated decisions produces systemic drift from organizational intent. In the software engineering domain, this manifests as codebase entropy — a gradual degradation of code quality that is invisible in any single commit but compounds across hundreds of agent-authored changes. Coding agents optimize for task completion: passing tests, satisfying immediate requirements, resolving the current error. Without explicit governance, they gravitate toward expedient implementations that introduce coupling, code duplication, and inconsistent patterns.

### 3.2 Security Vulnerabilities at Machine Speed

A human operator who introduces a security vulnerability does so in a single action that passes through existing review processes. An autonomous agent can introduce the same vulnerability pattern across dozens of systems or endpoints in a single session. Without security-aware governance, agents can propagate vulnerable patterns faster than security tooling can detect them — particularly when the agent generates output that is syntactically correct, passes validation, and satisfies functional requirements while containing subtle flaws that only manifest under adversarial conditions.

### 3.3 Architectural and Organizational Inconsistency

High-level structural decisions — which frameworks to use, how to organize modules, how to handle cross-cutting concerns, which communication patterns to follow — constrain implementation choices. Agents lacking persistent awareness of these decisions may produce implementations that are locally correct but globally inconsistent. An agent tasked with adding a new capability may implement it using a different pattern than the organization's established convention — not because the agent is incapable of following conventions, but because no governance mechanism ensures that conventions are consistently communicated and enforced across agent sessions.

### 3.4 Review Bottleneck Inversion

Traditional workflows assume that production is the bottleneck and review is relatively lightweight. Autonomous agents invert this ratio: production becomes nearly instantaneous, and human review becomes the critical bottleneck. Organizations that deploy agents without adjusting their review processes find themselves with a rapidly growing queue of agent-produced output that humans cannot review at the rate it is produced. The organizational response is often to rubber-stamp agent output — precisely the governance failure that SOSA is designed to prevent.

---

## 4. The SOSA™ Framework

SOSA defines four interdependent pillars that collectively govern agent behavior in production environments. No single pillar is sufficient in isolation; it is their integration that produces systems capable of sustained autonomous operation under enterprise constraints.

### 4.1 Supervised

Every agent in a SOSA-compliant system operates under a defined supervision policy. Human-in-the-loop checkpoints are not optional add-ons — they are first-class architectural primitives. Supervision is graduated: routine, low-impact tasks execute autonomously, while high-stakes actions require explicit human approval or are bounded by pre-authorized decision envelopes.

The supervision model is governed by an **impact scoring function**. Each agent action *a* is assigned an impact score *I(a)* computed from factors including magnitude, external visibility, reversibility, and sensitivity. The organization defines a risk threshold *θ*. Actions where *I(a) ≤ θ* execute autonomously. Actions where *I(a) > θ* are gated on supervisor approval.

> *For any agent action a with impact score I(a) > θ, execution is gated on supervisor approval S(a) = 1, where θ is a configurable organizational risk threshold.*

Critically, the threshold *θ* is not static. SOSA implements a **trust gradient** that adjusts based on observed agent performance. Agents that consistently produce correct outcomes for actions near the threshold boundary earn expanded autonomy. Agents that exhibit failure patterns are automatically escalated to tighter supervision. This creates an adaptive system where trust is earned through verifiable behavior, not assumed through configuration.

In the software engineering domain, the impact score *I(c)* for any code change *c* is computed from code-specific factors: the number of files modified, the criticality of the files touched (infrastructure vs. UI vs. documentation), the presence of security-sensitive patterns (authentication, authorization, cryptography, data access), the reversibility of the change (additive changes are more reversible than modifications to shared interfaces), and the blast radius (changes to shared libraries affect more consumers than changes to leaf modules).

**Table 1: Supervision Levels**

| Level | Scope | Review Requirement |
|-------|-------|--------------------|
| L0 — Auto | Low-impact, formatting, documentation | None (auto-approved) |
| L1 — Async | Single-scope, non-critical changes | Post-execution review |
| L2 — Pre-merge | Multi-scope, business logic | 1 human reviewer before execution |
| L3 — Gated | Security, infrastructure, shared components | Senior + security review |
| L4 — Prohibited | Production deployment, schema migration, financial transactions | Human-only execution |

The trust gradient operates at the agent-and-context level. An agent that consistently produces correct outcomes — measured by approval rates, defect rates, and scope compliance — earns expanded autonomy for that context. This creates a natural onboarding process: new agents start with tight supervision and earn broader authority through demonstrated reliability, mirroring the trust gradient applied to human team members joining a new organization.

**Living Documentation (Adaptive CLAUDE.md).** SOSA introduces a supervision mechanism that bridges sessions: each task, agent, or project maintains a living documentation file that serves as adaptive institutional memory. This document is updated at the end of each execution run when something new is learned — patterns discovered, edge cases encountered, architectural decisions made, failure modes identified, or supervision decisions recorded (what was escalated, approved, or rejected). Unlike static configuration, this living document evolves with the system, ensuring that agents do not repeat mistakes, re-discover known constraints, or lose context between sessions. The documentation also serves as a governance record: over time, it captures the history of trust-building between the agent and the organization, providing auditable evidence that supervision decisions were informed by accumulated experience rather than arbitrary defaults.

### 4.2 Orchestrated

Isolated agents produce isolated outcomes. In any non-trivial environment, agents must coordinate across temporal, informational, and toolchain dimensions. SOSA mandates an orchestration layer that manages this coordination explicitly rather than relying on ad-hoc inter-agent messaging.

The orchestrator maintains a **directed acyclic graph (DAG)** *G = (V, E)* where vertices represent agent tasks and edges encode data dependencies and temporal constraints. This structure ensures conflict-free concurrent execution: agents that share no data dependencies execute in parallel, while dependent tasks respect ordering constraints. The DAG is constructed from specifications, not inferred from runtime behavior, ensuring deterministic scheduling under normal operating conditions.

> *The orchestrator maintains a directed acyclic graph G = (V, E) where vertices represent agent tasks and edges encode data dependencies and temporal constraints, ensuring conflict-free concurrent execution.*

Context sharing between agents is mediated through **structured registries** rather than direct message passing. When one agent determines that a piece of context is relevant, it writes a structured context record to the shared registry. Downstream agents read these records on their next execution cycle. This decoupled architecture prevents cascading failures: if a downstream agent fails, the upstream context remains intact and available for retry.

In software engineering contexts, the orchestrator additionally enforces **merge serialization**: when multiple agents produce changes that touch overlapping files, the orchestrator sequences merges to prevent conflicts and ensures that each agent's changes are validated against the most current state of the codebase.

**Token efficiency is mandatory.** A bloated system wastes context window budget that should be allocated to actual work. SOSA's orchestration pillar requires that agent interactions are optimized for minimal overhead while maintaining governance fidelity.

### 4.3 Secured

Security in SOSA is not a perimeter — it is a property of every layer. Each agent runs in an isolated execution environment with scoped credentials, zero-trust network boundaries, and cryptographically verifiable audit trails. No agent can access resources beyond its declared permission set, and all inter-agent communication passes through authenticated channels.

> *Each agent Aᵢ is assigned a capability set Cᵢ ⊆ C enforced at runtime. Cross-agent communication requires mutual attestation: msg(Aᵢ, Aⱼ) is valid iff auth(Aᵢ) ∧ auth(Aⱼ) = true.*

Capabilities are not inherited from the orchestrator or from peer agents; they are explicitly declared in the agent's manifest and verified before every tool invocation.

**Sandboxed execution environments.** Each agent operates within a sandboxed environment that restricts access to authorized resources, limits network access to approved services, and prevents execution of arbitrary operations outside the agent's toolchain.

**Scoped permissions.** Each agent is assigned a capability set that specifies which resources, interfaces, and operations it may access. An agent tasked with one domain cannot access another domain's resources — not because it lacks the technical ability, but because the security layer enforces this boundary.

**Secrets isolation.** Agents must never have access to production credentials, API keys, or cryptographic material directly. The security layer ensures that environment variables, credential files, and secrets management systems are excluded from the agent's capability set. Agents that require service access use scoped, time-limited credentials issued by the orchestrator.

**Immutable audit trails.** Every action taken by every agent is logged to an immutable audit store. The audit trail includes the action type, timestamp, input parameters, output results, the agent's identity, and the authorization chain that permitted the action — including the reasoning chain that led to each decision. This provides complete forensic traceability, a requirement for regulatory compliance in financial services, healthcare, and government sectors.

### 4.4 Agents

SOSA agents are not scripts with LLM wrappers. They are goal-directed autonomous entities with persistent context, tool-use capabilities, and adaptive planning. Each agent possesses a defined role ontology, success metrics, and failure recovery strategies — enabling them to operate as reliable participants in a larger organizational system.

> *An agent is a tuple A = (R, T, M, P, K) where R is the role specification, T is the tool manifest, M is the memory/context store, P is the planning policy governing action selection, and K is the domain knowledge model.*

The **role specification R** is particularly consequential. Unlike generic agents that rely on prompt engineering to constrain behavior, SOSA agents have their domain boundaries, success criteria, and escalation triggers encoded in structured specifications that are enforced by the runtime, not merely suggested to the LLM. A financial reconciliation agent cannot be prompt-injected into sending emails — its tool manifest does not include email capabilities, and the security layer enforces this constraint at the API level. A coding agent tasked with frontend development cannot modify backend infrastructure code — the security layer enforces this boundary at the file system level.

The **domain knowledge model K** captures the agent's understanding of its operating context: the repository's architectural patterns and conventions, the dependency graph between modules, the team's standards and style guidelines, the history of recent changes and active work, and the known areas of fragility. K is populated through automated analysis at agent initialization and updated incrementally as the agent observes changes to its environment. Agents with a well-populated K produce output that is consistent with existing patterns; agents with a sparse K are restricted to lower-impact tasks until their knowledge model matures.

These roles are not merely labels — they are enforced by the security layer. Role boundaries ensure that the execution loop maintains its integrity even when all participants are autonomous agents.

---

## 5. The SOSA Execution Model

In a SOSA-compliant system, agent execution follows a three-phase loop: **Plan**, **Act**, and **Verify**. This loop operates at two timescales: the individual task level (seconds to minutes) and the organizational learning level (days to weeks).

### 5.1 Plan

During the planning phase, the agent decomposes its current objective into a sequence of operations, subject to the constraints in its capability set. The planning policy evaluates available actions against the agent's role specification, filtering out any actions that would violate domain boundaries or exceed the agent's authorization scope. The resulting plan is a partially ordered set of operations with explicit preconditions and expected postconditions.

Crucially, the plan is a **reviewable artifact**. For actions that exceed the supervision threshold, the plan itself is subject to human review before execution begins. This "plan review" is far more efficient than post-execution review — it allows the human supervisor to catch architectural mistakes, missing requirements, or misunderstood constraints before any work is done, preventing wasted agent compute and reducing review cycles.

### 5.2 Act

During the action phase, each planned step is executed against real external systems — APIs, databases, communication platforms, file systems, code repositories — with every interaction logged to the immutable audit store. Actions that exceed the impact threshold are paused and escalated to the appropriate supervisor. The orchestration layer monitors action execution for timeouts, errors, and unexpected state changes, triggering the agent's failure recovery strategy when anomalies are detected.

The action phase includes **inline verification checkpoints**: after each significant action, the agent validates that the change satisfies its postcondition. If a checkpoint fails, the agent enters a local recovery loop — attempting alternative approaches, consulting the domain knowledge model for similar patterns, or escalating to the orchestrator if recovery fails after a configurable number of attempts.

### 5.3 Verify

During the verification phase, the orchestrator evaluates the outcome against declared success criteria defined in the agent's role specification. Verification is not merely a boolean pass/fail check; it produces a structured evaluation record that feeds into the trust gradient.

In software engineering contexts, verification is uniquely rich because software provides objective verification mechanisms: the full test suite passes, static analysis produces no new warnings, security scanning detects no new vulnerabilities, coverage meets or exceeds thresholds, the change is consistent with the architectural patterns in K, and the diff is within the expected scope.

> *The trust gradient for agents is computed as: τ(Aᵢ, Cⱼ) = f(pass_rate, approval_rate, defect_rate, scope_compliance) where Aᵢ is the agent and Cⱼ is the context. Agents whose τ exceeds the trust threshold earn progressive autonomy expansions.*

This creates a continuous improvement mechanism: the system's governance posture adapts to observed agent reliability rather than relying on static, manually configured trust levels. Over time, well-performing agents require less human intervention, while unreliable agents receive proportionally more oversight — precisely the adaptive trust model that static rule-based systems cannot achieve.

---

## 6. SOSA Across the Software Development Lifecycle

The SOSA methodology applies not just to individual agent sessions but to the entire software project lifecycle. We map SOSA governance to each SDLC phase, demonstrating that principled agent governance extends from initial planning through production monitoring.

### 6.1 Requirements and Planning

SOSA Planner agents analyze requirements documents, user stories, and stakeholder inputs to produce structured implementation plans. The Supervised pillar ensures that plans for high-impact features require human approval. The Orchestrated pillar ensures that planning outputs are shared through code context registries, providing downstream agents with the architectural intent behind each requirement. Planning agents operate at supervision level L2 or L3, ensuring human oversight of consequential architectural decisions.

### 6.2 Implementation

Implementer agents execute plans by writing production code. SOSA governance ensures that each implementer operates within its scoped permissions (Secured), follows the architectural contracts defined by the planner (Orchestrated), submits changes for review at the appropriate supervision level (Supervised), and maintains a complete audit trail of every file modification and the reasoning behind it (Agents). Multiple implementers can work concurrently on non-overlapping modules, with the orchestrator preventing merge conflicts and ensuring interface consistency.

### 6.3 Testing

Tester agents generate test cases from implementation specifications, execute test suites, analyze failures, and report coverage gaps. Under SOSA, tester agents are *independent* from implementer agents — they cannot be configured or influenced by the agent that wrote the code they are testing. This separation of concerns, enforced by the security layer, prevents the common anti-pattern where an agent writes both the implementation and the tests that validate it, creating a closed loop that may miss the very failure modes the tests should detect.

### 6.4 Code Review

Reviewer agents provide automated code review as a complement to (not replacement for) human review. SOSA-compliant reviewer agents evaluate code against the codebase knowledge model K, checking for pattern consistency, security anti-patterns, performance regressions, and documentation completeness. The Supervised pillar ensures that reviewer agents escalate concerns they cannot resolve — ambiguous architectural decisions, novel security patterns, or trade-offs that require business context — to human reviewers rather than making autonomous judgments beyond their competence.

### 6.5 Deployment and Release

Deployer agents manage CI/CD pipelines, orchestrate build processes, and coordinate releases. Under SOSA, deployment is typically classified at supervision level L3 or L4: production deployments require human approval regardless of the agent's trust score. The Secured pillar ensures that deployer agents access production infrastructure through scoped, time-limited credentials and that every deployment action is logged with full attribution. The Orchestrated pillar ensures that deployment timing respects dependencies — database migrations complete before application deployment, feature flags are configured before consumer-facing changes go live.

### 6.6 Monitoring and Incident Response

Monitor agents observe production systems for anomalies, correlate errors with recent deployments, and initiate automated responses. SOSA governance constrains monitor agents to *diagnostic* actions (reading logs, querying metrics, generating reports) at L0-L1 supervision, while *remediation* actions (rollbacks, configuration changes, traffic rerouting) require L3 supervision. This prevents an overeager monitor agent from triggering cascading rollbacks in response to transient anomalies while still enabling rapid automated detection and escalation.

---

## 7. Implications for Adoption

The SOSA methodology directly addresses the primary barriers to enterprise AI agent adoption.

**Accountability.** By requiring full audit trails and graduated supervision, SOSA satisfies regulatory and internal governance requirements. Every agent action is traceable to a specific authorization chain. When an agent makes an error, the audit trail identifies exactly what happened, when, and why — enabling rapid remediation rather than opaque debugging. This accountability structure aligns with the requirements of NIST AI RMF, EU AI Act high-risk provisions, and SOC 2 compliance frameworks.

**Reliability.** By mandating orchestration and structured inter-agent context sharing, SOSA eliminates the coordination failures that plague multi-agent deployments. The DAG-based scheduling ensures that agents respect data dependencies. The structured registry model prevents cascading failures. The Plan-Act-Verify loop with its trust gradient ensures that unreliable agents are automatically constrained before they can cause organizational damage.

**Compliance.** By treating security as a first-class design constraint rather than an afterthought, SOSA enables deployment in environments where data sensitivity precludes the use of conventional SaaS-based AI solutions. The zero-trust architecture, scoped credentials, and data-in-transit processing model mean that sensitive data never resides on third-party servers — a requirement for financial services, healthcare, legal, and government contexts.

**Code Quality Assurance.** By mandating the Plan-Act-Verify loop with codebase-aware governance, SOSA ensures that agent-authored code meets the same quality standards as human-authored code. The domain knowledge model K provides agents with the contextual awareness that prevents architectural drift. The trust gradient ensures that quality standards are not static rules but adaptive expectations that tighten in response to observed failures and relax in response to demonstrated reliability.

**Scalable Human Oversight.** The graduated supervision model solves the review bottleneck inversion. By allowing low-impact changes to proceed autonomously (L0-L1) while requiring human review only for consequential changes (L2-L4), SOSA concentrates human attention where it adds the most value. The trust gradient ensures that this delegation is earned, not assumed — and automatically revoked when agent performance degrades.

**Multi-Agent Team Coordination.** As organizations deploy multiple agents — potentially from different vendors — across the same systems, the orchestration layer becomes essential. SOSA's DAG-based task coordination, structured context registries, and merge serialization prevent the chaos that would result from multiple uncoordinated agents making concurrent changes. The orchestration layer treats agents as team members with defined roles, responsibilities, and communication protocols — not as isolated tools operating in parallel.

These properties collectively justify premium positioning. Organizations adopting SOSA-compliant platforms are not deploying a chatbot or an automation script; they are deploying a governed, auditable, enterprise-grade AI operations layer.

---

## 8. Conclusion

SOSA represents a necessary evolution from ad-hoc AI agent deployment to principled, production-grade AI operations. By integrating supervision, orchestration, security, and agent design into a unified methodology, SOSA provides organizations with a framework that scales from initial pilot to full operational deployment without sacrificing governance or accountability — whether the agents automate business operations or write production code.

The methodology demonstrates that principled governance does not require sacrificing the productivity gains that AI agents provide. Graduated supervision levels for code changes, orchestrated multi-agent development coordination, zero-trust security for code access and execution, and formally specified agent roles with codebase knowledge models — these governance primitives make agents more reliable, not less productive. The Plan-Act-Verify execution model, with its adaptive trust gradient, creates a system where agents earn autonomy through verifiable performance rather than demanding it through configuration.

The implications extend beyond individual tools. As the industry converges on agent-assisted workflows as a standard practice, organizations that adopt structured governance frameworks will deploy agents that produce consistent, secure, and architecturally coherent output. Organizations that do not will accumulate agent-authored technical debt and operational drift at a pace that no human team can remediate.

Future work includes formal verification of agent supervision policies using model-checking techniques, development of cross-organizational SOSA compliance certification standards, standardized domain knowledge model formats for interoperability between agents from different vendors, empirical measurement of SOSA governance overhead across different organization sizes and complexities, and extension of the trust gradient model to incorporate multi-stakeholder approval chains for regulated industries.

---

## References

[1] Wu, Q., et al. "AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation." arXiv:2308.08155, 2023.

[2] Moura, J. "CrewAI: Framework for Orchestrating Role-Playing Autonomous AI Agents." GitHub, 2024.

[3] LangChain. "LangGraph: Build Stateful, Multi-Agent Applications with LLMs." LangChain Documentation, 2024.

[4] Yao, S., et al. "ReAct: Synergizing Reasoning and Acting in Language Models." ICLR, 2023.

[5] Wang, L., et al. "Plan-and-Solve Prompting: Improving Zero-Shot Chain-of-Thought Reasoning." ACL, 2023.

[6] Shinn, N., et al. "Reflexion: Language Agents with Verbal Reinforcement Learning." NeurIPS, 2023.

[7] Chen, M., et al. "Evaluating Large Language Models Trained on Code." arXiv:2107.03374, 2021.

[8] Anthropic. "Claude Code: Agentic Coding Tool." Product documentation, 2025.

[9] Cognition AI. "Devin: The First AI Software Engineer." Product announcement, 2024.

[10] National Institute of Standards and Technology. "AI Risk Management Framework (AI RMF 1.0)." NIST, January 2023.

[11] European Parliament. "Regulation (EU) 2024/1689 Laying Down Harmonised Rules on Artificial Intelligence (AI Act)." Official Journal of the European Union, 2024.

[12] ISO/IEC 42001:2023. "Information Technology — Artificial Intelligence — Management System." International Organization for Standardization, 2023.

[13] Dennis, J.B. and Van Horn, E.C. "Programming Semantics for Multiprogrammed Computations." Communications of the ACM, 9(3), 1966.

[14] Rose, S., et al. "Zero Trust Architecture." NIST Special Publication 800-207, August 2020.

[15] Kim, G., et al. "The DevOps Handbook: How to Create World-Class Agility, Reliability, & Security in Technology Organizations." IT Revolution Press, 2016.

---

*© 2026 MSApps Research. All rights reserved. SOSA™ is a trademark of MSApps.*
