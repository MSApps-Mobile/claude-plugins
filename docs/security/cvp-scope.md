# CVP scope — which tier MSApps needs

Anthropic's Cyber Verification Program (CVP) has four access levels. Source: the brief on card 54ABAl7N, as of 2026-10-15. **This has not been checked against Anthropic's current program page.** Re-check it, and record the URL and date here, before relying on it.

| Tier | Covers | Application |
|------|--------|-------------|
| **Default access** | Secure coding, code review, patching, finding vulnerabilities in code you own, alert triage | None |
| **Defense Access** | Vulnerability validation, malware analysis, detection engineering, SOC work, incident response | Yes. Requires MFA (phishing-resistant from 2026-12-15) and strict API key handling |
| **Red Team** | Offensive testing | Yes. Named security contacts, per-user attribution, IR, no shared sign-ins |
| **Specialized** | Case by case | Yes |

All tiers require retention and monitoring of CVP traffic.

Policy: **apply for the narrowest tier our real work needs.**

## Our real security workflows

| # | Workflow | What it involves | Where it lives | Tier it needs |
|---|----------|------------------|----------------|---------------|
| W-1 | **SOSA™ governance** | Writing and running our own lint/eval scripts over our own plugins. Classifying MCP tool calls by impact. Designing approval gates and audit logging for agents | `scripts/sosa-*.sh`, `plugins/sosa-governor`, `plugins/sosa-compliance-checker`, [SOSA.md](../SOSA.md) | **Default**: secure coding |
| W-2 | **Secure code review of our own repos** | Reviewing PRs in `MSApps-Mobile/*` for injection (shell, prompt, GitHub Actions script injection), hardcoded secrets, unsafe file handling and over-broad permissions, then writing the patch | PRs on this repo | **Default**: code review, patching, finding vulns in code we own |
| W-3 | **Dependency / vulnerability triage** | Reading Dependabot and secret-scanning alerts on our repos. Deciding whether an advisory is reachable from our code. Choosing an upgrade or mitigation. Rotating a leaked credential | Repo → Security tab (controls C-2, C-3) | **Default**: alert triage, patching |

**Conclusion: everything we do today fits default access. No application is required for it.**

### When Defense Access would become necessary

Only if a human confirms we need **vulnerability validation**: building or running a proof-of-concept to
prove that a published CVE in a third-party dependency is exploitable through our code, beyond reading the
advisory and tracing reachability. W-3 does not do this today. If that need is confirmed:

- the narrowest fitting tier is **Defense Access**, limited to vulnerability validation of **dependencies
  of repositories we own**, in local or CI sandboxes we control;
- we apply only after the CVP-blocking gaps in [controls.md](controls.md) (G-2 to G-9) are
  closed with evidence.

We see no need for malware analysis, detection engineering, SOC or incident-response tooling.

## What we will NOT do

Under any tier, with or without CVP approval, MSApps will **not** use Claude for:

- **Penetration testing or red-team work** of any kind, including against our own production
  infrastructure. We do not offer it as a service.
- Scanning, probing or exploiting **systems we do not own** or do not hold a written engagement for.
  Today we hold no such engagements.
- Writing **weaponised exploits**, malware, persistence, command-and-control or evasion tooling.
- **Credential attacks**: phishing kits, password spraying, cracking.
- Analysing **customer data or customer systems** under CVP access. Client work is out of CVP scope for
  this application.

A request in any of these categories is out of scope. Claude declining it is the expected behaviour, not
an eval failure (see scenario `boundary-third-party-pentest` in [`evals/cvp`](../../evals/cvp/)).

## How we will know default access is enough

[`evals/cvp/`](../../evals/cvp/) holds 8 scenarios drawn from W-1 to W-3, plus 1 boundary scenario. They
are run on default access. A **model refusal** or **classifier block** on an in-scope scenario is the
signal that the work needs a higher tier, and the log records the two separately. A clean run on default
access is the evidence that we should **not** apply.
